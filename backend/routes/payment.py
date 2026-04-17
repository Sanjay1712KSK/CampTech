import hashlib
import hmac
import os

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from database.db import get_db
from models.models import PremiumSnapshot, UserBehavior
from schemas.insurance_schema import (
    BankTransactionHistoryResponse,
    InsuranceSummaryResponse,
    LinkBankRequest,
    LinkBankResponse,
    PaymentOrderCreateRequest,
    PaymentOrderCreateResponse,
    PaymentResponse,
    PaymentVerifyRequest,
    PaymentVerifyResponse,
    PayPremiumRequest,
)
from services.bank_service import debit, insurance_summary, link_account, log_transaction, transaction_history
from services.blockchain_service import create_policy_record, log_to_blockchain
from services.premium_engine import baseline_value, calculate_weekly_premium
from services.policy_service import create_policy

router = APIRouter(prefix='/payment', tags=['payment'])

try:
    import razorpay  # type: ignore
except ImportError:  # pragma: no cover
    razorpay = None


RAZORPAY_KEY_ID = os.getenv('RAZORPAY_KEY_ID', '').strip()
RAZORPAY_KEY_SECRET = os.getenv('RAZORPAY_KEY_SECRET', '').strip()
RAZORPAY_CURRENCY = 'INR'
POLICY_VALIDITY_DAYS = 7


def _razorpay_client():
    if razorpay is None or not RAZORPAY_KEY_ID or not RAZORPAY_KEY_SECRET:
        return None
    return razorpay.Client(auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET))


def _activate_policy_for_payment(
    *,
    db: Session,
    user_id: int,
    amount: float,
    coverage: float,
    provider_reference: str,
    provider: str,
):
    policy = create_policy(user_id=user_id, db=db)
    latest_premium_snapshot = (
        db.query(PremiumSnapshot)
        .filter(PremiumSnapshot.user_id == int(user_id))
        .order_by(PremiumSnapshot.created_at.desc(), PremiumSnapshot.id.desc())
        .first()
    )
    if latest_premium_snapshot and latest_premium_snapshot.policy_id is None:
        latest_premium_snapshot.policy_id = policy.id
        if not latest_premium_snapshot.coverage:
            latest_premium_snapshot.coverage = float(coverage)

    policy_chain_resp = create_policy_record(
        user_id=user_id,
        premium=amount,
        baseline_income=baseline_value(user_id, db),
        policy_id=policy.id,
        db=db,
    )
    txn = log_transaction(
        db=db,
        user_id=user_id,
        transaction_type='PREMIUM_PAYMENT',
        amount=amount,
        reference_id=provider_reference,
        metadata={
            'amount': amount,
            'coverage': coverage,
            'policy_id': policy.id,
            'provider': provider,
            'remark': f'Weekly premium paid for policy #{policy.id}',
        },
    )
    chain_resp = log_to_blockchain(
        event_type='premium_payment',
        payload={
            'user_id': user_id,
            'amount': amount,
            'coverage': coverage,
            'policy_id': policy.id,
            'reference_id': txn.reference_id,
            'policy_end_date': policy.end_date.isoformat(),
            'transaction_id': txn.reference_id,
            'provider': provider,
        },
        db=db,
    )
    return policy, txn, (
        policy_chain_resp.get('tx_hash')
        or chain_resp.get('tx_hash')
        or chain_resp.get('transaction_id')
    )


def _build_policy_payload(policy, amount: float, coverage: float) -> dict:
    return {
        'user_id': int(policy.user_id),
        'premium_paid': float(amount),
        'coverage': float(coverage),
        'validity': f'{POLICY_VALIDITY_DAYS} days',
        'status': policy.status,
        'policy_id': policy.id,
        'start_date': policy.start_date,
        'end_date': policy.end_date,
    }


def _verify_razorpay_signature(order_id: str, payment_id: str, signature: str) -> bool:
    if not RAZORPAY_KEY_SECRET:
        return False
    payload = f'{order_id}|{payment_id}'.encode()
    digest = hmac.new(RAZORPAY_KEY_SECRET.encode(), payload, hashlib.sha256).hexdigest()
    return hmac.compare_digest(digest, signature)


@router.get('/summary', response_model=InsuranceSummaryResponse)
def payment_summary_endpoint(user_id: int = Query(..., gt=0), db: Session = Depends(get_db)):
    return insurance_summary(db=db, user_id=user_id)


@router.get('/transactions', response_model=BankTransactionHistoryResponse)
def payment_transaction_history_endpoint(
    user_id: int = Query(..., gt=0),
    limit: int = Query(default=10, ge=1, le=20),
    db: Session = Depends(get_db),
):
    return transaction_history(db=db, user_id=user_id, limit=limit)


@router.post('/link-bank', response_model=LinkBankResponse)
def link_bank_endpoint(payload: LinkBankRequest, db: Session = Depends(get_db)):
    account = link_account(
        db=db,
        user_id=payload.user_id,
        account_number=payload.account_number,
        ifsc=payload.ifsc,
    )
    db.commit()
    db.refresh(account)
    return {
        'status': 'LINKED',
        'user_id': payload.user_id,
        'balance': float(account.balance),
    }


@router.post('/create-order', response_model=PaymentOrderCreateResponse)
def create_order_endpoint(payload: PaymentOrderCreateRequest, db: Session = Depends(get_db)):
    premium = calculate_weekly_premium(
        user_id=payload.user_id,
        lat=payload.lat,
        lon=payload.lon,
        db=db,
    )
    amount = float(premium['weekly_premium'])
    coverage = float(premium['coverage'])
    amount_paise = max(100, int(round(amount * 100)))

    client = _razorpay_client()
    provider = 'simulated'
    order_id = f'order_demo_{payload.user_id}_{amount_paise}'
    if client is not None:
        order = client.order.create(
            {
                'amount': amount_paise,
                'currency': RAZORPAY_CURRENCY,
                'payment_capture': 1,
                'notes': {
                    'user_id': str(payload.user_id),
                    'coverage': str(coverage),
                    'validity': f'{POLICY_VALIDITY_DAYS} days',
                },
            }
        )
        order_id = order['id']
        provider = 'razorpay_test_mode'

    existing = (
        db.query(UserBehavior)
        .filter(
            UserBehavior.user_id == int(payload.user_id),
            UserBehavior.event_type == 'payment_order',
            UserBehavior.event_value == order_id,
        )
        .first()
    )
    if existing is None:
        existing = UserBehavior(
            user_id=int(payload.user_id),
            event_type='payment_order',
            event_value=order_id,
        )
        db.add(existing)
    existing.confidence_score = 1.0
    existing.behavior_metadata = {
        'provider': provider,
        'amount': amount,
        'amount_paise': amount_paise,
        'coverage': coverage,
        'currency': RAZORPAY_CURRENCY,
        'status': 'CREATED',
        'premium_snapshot_id': premium.get('premium_snapshot_id'),
    }
    db.commit()

    return {
        'status': 'CREATED',
        'user_id': payload.user_id,
        'order_id': order_id,
        'amount': amount,
        'amount_paise': amount_paise,
        'currency': RAZORPAY_CURRENCY,
        'key_id': RAZORPAY_KEY_ID,
        'premium': amount,
        'coverage': coverage,
        'validity': f'{POLICY_VALIDITY_DAYS} days',
        'provider': provider,
    }


@router.post('/verify', response_model=PaymentVerifyResponse)
def verify_payment_endpoint(payload: PaymentVerifyRequest, db: Session = Depends(get_db)):
    pending_order = (
        db.query(UserBehavior)
        .filter(
            UserBehavior.user_id == int(payload.user_id),
            UserBehavior.event_type == 'payment_order',
            UserBehavior.event_value == payload.razorpay_order_id,
        )
        .order_by(UserBehavior.observed_at.desc(), UserBehavior.id.desc())
        .first()
    )
    if pending_order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Payment order not found')

    metadata = pending_order.behavior_metadata or {}
    if metadata.get('status') == 'VERIFIED':
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='Payment already verified')

    signature_valid = _verify_razorpay_signature(
        payload.razorpay_order_id,
        payload.razorpay_payment_id,
        payload.razorpay_signature,
    )
    if not signature_valid:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Payment signature verification failed')

    amount = float(metadata.get('amount') or 0.0)
    coverage = float(metadata.get('coverage') or 0.0)
    if amount <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Invalid premium amount')

    policy, txn, blockchain_txn_id = _activate_policy_for_payment(
        db=db,
        user_id=payload.user_id,
        amount=amount,
        coverage=coverage,
        provider_reference=payload.razorpay_payment_id,
        provider=str(metadata.get('provider') or 'razorpay_test_mode'),
    )
    pending_order.confidence_score = 1.0
    pending_order.behavior_metadata = {
        **metadata,
        'status': 'VERIFIED',
        'razorpay_payment_id': payload.razorpay_payment_id,
        'razorpay_signature': payload.razorpay_signature,
        'transaction_id': txn.reference_id,
        'policy_id': policy.id,
    }
    db.commit()

    return {
        'status': 'SUCCESS',
        'user_id': payload.user_id,
        'amount': amount,
        'transaction_id': txn.reference_id,
        'blockchain_txn_id': blockchain_txn_id,
        'provider': str(metadata.get('provider') or 'razorpay_test_mode'),
        'policy': _build_policy_payload(policy, amount, coverage),
    }


@router.post('/pay-premium', response_model=PaymentResponse)
def pay_premium_endpoint(payload: PayPremiumRequest, db: Session = Depends(get_db)):
    account = debit(db=db, user_id=payload.user_id, amount=payload.amount)
    latest_premium_snapshot = (
        db.query(PremiumSnapshot)
        .filter(PremiumSnapshot.user_id == int(payload.user_id))
        .order_by(PremiumSnapshot.created_at.desc(), PremiumSnapshot.id.desc())
        .first()
    )
    policy, txn, blockchain_txn_id = _activate_policy_for_payment(
        db=db,
        user_id=payload.user_id,
        amount=payload.amount,
        coverage=float(latest_premium_snapshot.coverage) if latest_premium_snapshot else 0.0,
        provider_reference='',
        provider='internal_wallet',
    )
    db.commit()
    db.refresh(account)
    return {
        'status': 'SUCCESS',
        'user_id': payload.user_id,
        'amount': float(payload.amount),
        'balance': float(account.balance),
        'transaction_id': txn.reference_id,
        'blockchain_txn_id': blockchain_txn_id,
    }
