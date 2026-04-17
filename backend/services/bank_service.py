import json
import uuid

from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from models.bank_account import BankAccount, BankTransaction
from models.insurance import Claim
from models.models import ClaimHistory
from models.user_model import User
from services.policy_service import get_claimable_policy, get_latest_policy


DEFAULT_OPENING_BALANCE = 10000.0


def _round(value: float) -> float:
    return float(round(float(value), 2))


def _require_user(db: Session, user_id: int) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')
    return user


def get_account(db: Session, user_id: int) -> BankAccount | None:
    return db.query(BankAccount).filter(BankAccount.user_id == int(user_id)).first()


def link_account(
    db: Session,
    user_id: int,
    account_number: str,
    ifsc: str,
    opening_balance: float = DEFAULT_OPENING_BALANCE,
) -> BankAccount:
    _require_user(db, int(user_id))
    user = _require_user(db, int(user_id))

    account = get_account(db, user_id)
    if account is None:
        account = BankAccount(
            user_id=int(user_id),
            account_number=account_number,
            ifsc=ifsc.upper(),
            balance=_round(opening_balance),
        )
        db.add(account)
    else:
        account.account_number = account_number
        account.ifsc = ifsc.upper()
        if account.balance is None:
            account.balance = _round(opening_balance)

    db.flush()
    return account


def log_transaction(
    db: Session,
    user_id: int,
    transaction_type: str,
    amount: float,
    status_value: str = 'SUCCESS',
    reference_id: str | None = None,
    metadata: dict | None = None,
) -> BankTransaction:
    txn = BankTransaction(
        user_id=int(user_id),
        transaction_type=transaction_type,
        amount=_round(amount),
        status=status_value,
        reference_id=reference_id or str(uuid.uuid4()),
        metadata_json=json.dumps(metadata or {}),
    )
    db.add(txn)
    db.flush()
    return txn


def debit(db: Session, user_id: int, amount: float) -> BankAccount:
    account = get_account(db, int(user_id))
    if account is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Bank account not linked')

    amount = _round(amount)
    if amount <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Amount must be greater than zero')
    if account.balance < amount:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Insufficient balance')

    account.balance = _round(account.balance - amount)
    db.flush()
    return account


def credit(db: Session, user_id: int, amount: float) -> BankAccount:
    account = get_account(db, int(user_id))
    if account is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Bank account not linked')

    amount = _round(amount)
    if amount <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Amount must be greater than zero')

    account.balance = _round(account.balance + amount)
    db.flush()
    return account


def insurance_summary(db: Session, user_id: int) -> dict:
    user = _require_user(db, int(user_id))
    account = get_account(db, int(user_id))
    total_paid = (
        db.query(func.coalesce(func.sum(BankTransaction.amount), 0.0))
        .filter(
            BankTransaction.user_id == int(user_id),
            BankTransaction.transaction_type == 'PREMIUM_PAYMENT',
            BankTransaction.status == 'SUCCESS',
        )
        .scalar()
    )
    total_claimed = (
        db.query(func.coalesce(func.sum(BankTransaction.amount), 0.0))
        .filter(
            BankTransaction.user_id == int(user_id),
            BankTransaction.transaction_type.in_(['CLAIM_PAYOUT', 'MANUAL_CLAIM_PAYOUT']),
            BankTransaction.status == 'SUCCESS',
        )
        .scalar()
    )
    last_payout = (
        db.query(BankTransaction)
        .filter(
            BankTransaction.user_id == int(user_id),
            BankTransaction.transaction_type.in_(['CLAIM_PAYOUT', 'MANUAL_CLAIM_PAYOUT']),
            BankTransaction.status == 'SUCCESS',
        )
        .order_by(BankTransaction.created_at.desc(), BankTransaction.id.desc())
        .first()
    )
    latest_claim = (
        db.query(Claim)
        .filter(Claim.user_id == int(user_id))
        .order_by(Claim.created_at.desc(), Claim.id.desc())
        .first()
    )

    latest_claim_reason = None
    if latest_claim and latest_claim.reasons_json:
        try:
            parsed_reasons = json.loads(latest_claim.reasons_json)
            if isinstance(parsed_reasons, list) and parsed_reasons:
                latest_claim_reason = str(parsed_reasons[0])
        except json.JSONDecodeError:
            latest_claim_reason = None
    settled_claim = (
        db.query(ClaimHistory)
        .filter(
            ClaimHistory.user_id == int(user_id),
            ClaimHistory.status == 'APPROVED',
            ClaimHistory.approved_payout > 0,
        )
        .order_by(ClaimHistory.claim_date.desc(), ClaimHistory.id.desc())
        .first()
    )
    recent_transactions = (
        db.query(BankTransaction)
        .filter(BankTransaction.user_id == int(user_id))
        .order_by(BankTransaction.created_at.desc(), BankTransaction.id.desc())
        .limit(5)
        .all()
    )
    policy = get_latest_policy(int(user_id), db)
    claimable_policy = get_claimable_policy(int(user_id), db)

    if policy is None:
        policy_status = 'NOT PURCHASED'
        claim_ready = False
        claim_message = 'Buy weekly insurance to activate claims'
        policy_start = None
        policy_end = None
    else:
        policy_status = policy.status
        claim_ready = claimable_policy is not None
        claim_message = (
            'Ready to claim previous completed week'
            if claim_ready
            else 'Claim available after the insured week completes'
        )
        policy_start = policy.start_date
        policy_end = policy.end_date

    if settled_claim is not None or (latest_claim and latest_claim.status == 'APPROVED' and last_payout):
        claim_ready = False
        claim_message = 'Previous completed week was already claimed and paid'
    elif latest_claim and latest_claim.status in {'REJECTED', 'FLAGGED'} and latest_claim_reason:
        claim_ready = False
        claim_message = latest_claim_reason

    return {
        'user_id': int(user_id),
        'bank_linked': account is not None,
        'account_number_masked': f'****{account.account_number[-4:]}' if account is not None and account.account_number else None,
        'ifsc': account.ifsc if account is not None else None,
        'balance': _round(account.balance) if account is not None else None,
        'total_paid': _round(total_paid or 0.0),
        'total_claimed': _round(total_claimed or 0.0),
        'policy_status': policy_status,
        'policy_start': policy_start,
        'policy_end': policy_end,
        'claim_ready': claim_ready,
        'claim_message': claim_message,
        'location_enabled': bool(user.location_enabled),
        'last_payout': _round(last_payout.amount) if last_payout else 0.0,
        'payout_status': last_payout.status if last_payout else None,
        'payout_transaction_id': last_payout.reference_id if last_payout else None,
        'payout_time': last_payout.created_at.isoformat() if last_payout and last_payout.created_at else None,
        'latest_claim_status': settled_claim.status if settled_claim else (latest_claim.status if latest_claim else None),
        'recent_remarks': [
            (
                json.loads(txn.metadata_json).get('remark')
                if txn.metadata_json
                else None
            )
            or f'{txn.transaction_type} of Rs {_round(txn.amount)}'
            for txn in recent_transactions
        ],
    }


def transaction_history(db: Session, user_id: int, limit: int = 10) -> dict:
    _require_user(db, int(user_id))
    transactions = (
        db.query(BankTransaction)
        .filter(BankTransaction.user_id == int(user_id))
        .order_by(BankTransaction.created_at.desc(), BankTransaction.id.desc())
        .limit(max(1, min(int(limit), 20)))
        .all()
    )
    items = []
    for txn in transactions:
        metadata = {}
        if txn.metadata_json:
            try:
                metadata = json.loads(txn.metadata_json)
            except json.JSONDecodeError:
                metadata = {}
        items.append(
            {
                'transaction_id': str(txn.id),
                'transaction_type': txn.transaction_type,
                'amount': _round(txn.amount),
                'status': txn.status,
                'reference_id': txn.reference_id,
                'remark': metadata.get('remark'),
                'created_at': txn.created_at.isoformat() if txn.created_at else '',
            }
        )
    return {
        'user_id': int(user_id),
        'transactions': items,
    }
