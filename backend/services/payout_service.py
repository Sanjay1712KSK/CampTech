from __future__ import annotations

import os
import secrets
import time
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from models.bank_account import BankAccount
from services.bank_service import credit, get_account, log_transaction

try:
    import razorpay  # type: ignore
except ImportError:  # pragma: no cover - optional dependency at runtime
    razorpay = None


RAZORPAY_KEY_ID = os.getenv('RAZORPAY_KEY_ID', '').strip()
RAZORPAY_KEY_SECRET = os.getenv('RAZORPAY_KEY_SECRET', '').strip()


def _utcnow_iso() -> str:
    return datetime.now(UTC).replace(tzinfo=None).isoformat()


def _round(value: float) -> float:
    return float(round(float(value), 2))


def _razorpay_client():
    if razorpay is None or not RAZORPAY_KEY_ID or not RAZORPAY_KEY_SECRET:
        return None
    return razorpay.Client(auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET))


def _ensure_payout_account(db: Session, user_id: int) -> BankAccount:
    account = get_account(db, int(user_id))
    if account is None:
        account = BankAccount(
            user_id=int(user_id),
            account_number=f'MOCK{int(user_id):08d}',
            ifsc='RZRP0000001',
            balance=0.0,
        )
        db.add(account)
        db.flush()
    return account


def _smart_payout_amount(amount: float, fraud_score: float | None) -> tuple[float, float]:
    score = float(fraud_score or 0.0)
    if score < 0.3:
        multiplier = 1.0
    elif score <= 0.6:
        multiplier = 0.8
    else:
        multiplier = 0.0
    return _round(amount * multiplier), multiplier


def process_payout(
    *,
    db: Session,
    user_id: int,
    claim_id: str,
    amount: float,
    claim_status: str,
    fraud_decision: str,
    fraud_score: float | None = None,
    user_bank_details: dict | None = None,
) -> dict:
    started = time.perf_counter()
    if str(claim_status).upper() != 'APPROVED':
        return {
            'status': 'SKIPPED',
            'amount_paid': 0.0,
            'transaction_id': None,
            'processing_time': f'{time.perf_counter() - started:.1f} seconds',
            'message': 'Claim is not approved for payout',
        }
    if str(fraud_decision).upper() != 'APPROVED':
        return {
            'status': 'SKIPPED',
            'amount_paid': 0.0,
            'transaction_id': None,
            'processing_time': f'{time.perf_counter() - started:.1f} seconds',
            'message': 'Fraud review did not approve this payout',
        }

    amount_paid, multiplier = _smart_payout_amount(amount, fraud_score)
    if amount_paid <= 0:
        return {
            'status': 'SKIPPED',
            'amount_paid': 0.0,
            'transaction_id': None,
            'processing_time': f'{time.perf_counter() - started:.1f} seconds',
            'message': 'Smart payout rules blocked this transfer',
        }

    account = _ensure_payout_account(db, user_id)
    client = _razorpay_client()
    provider = 'simulated'
    provider_reference = f'txn_{secrets.token_hex(8)}'
    try:
        if client is not None:
            provider = 'razorpay_test_mode'
            provider_reference = f'txn_{secrets.token_hex(8)}'
    except Exception:
        provider = 'simulated'

    credit(db=db, user_id=user_id, amount=amount_paid)
    processed_at = _utcnow_iso()
    transaction = log_transaction(
        db=db,
        user_id=user_id,
        transaction_type='CLAIM_PAYOUT',
        amount=amount_paid,
        status_value='SUCCESS',
        reference_id=provider_reference,
        metadata={
            'claim_id': claim_id,
            'provider': provider,
            'fraud_score': fraud_score,
            'payout_multiplier': multiplier,
            'beneficiary': user_bank_details
            or {
                'account_number_masked': f'****{account.account_number[-4:]}',
                'ifsc': account.ifsc,
            },
            'remark': f'Instant payout credited for {claim_id}',
            'processed_at': processed_at,
        },
    )
    processing_time = f'{time.perf_counter() - started:.1f} seconds'
    return {
        'status': 'SUCCESS',
        'amount_paid': amount_paid,
        'amount': amount_paid,
        'transaction_id': transaction.reference_id,
        'processed_at': processed_at,
        'timestamp': processed_at,
        'processing_time': processing_time,
        'message': 'Payout successfully credited',
        'balance': _round(account.balance),
        'provider': provider,
    }


def execute_instant_payout(
    *,
    db: Session,
    user_id: int,
    amount: float,
    claim_id: str,
    metadata: dict | None = None,
) -> dict:
    metadata = metadata or {}
    return process_payout(
        db=db,
        user_id=user_id,
        claim_id=claim_id,
        amount=amount,
        claim_status='APPROVED',
        fraud_decision='APPROVED',
        fraud_score=metadata.get('fraud_score'),
        user_bank_details=metadata.get('user_bank_details'),
    )
