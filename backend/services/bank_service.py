import json
import uuid

from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from models.bank_account import BankAccount, BankTransaction
from models.insurance import Claim
from models.user_model import User
from services.policy_service import get_latest_policy


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
    _require_user(db, int(user_id))
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
    recent_transactions = (
        db.query(BankTransaction)
        .filter(BankTransaction.user_id == int(user_id))
        .order_by(BankTransaction.created_at.desc(), BankTransaction.id.desc())
        .limit(5)
        .all()
    )
    policy = get_latest_policy(int(user_id), db)

    if policy is None:
        policy_status = 'NOT_PURCHASED'
        claim_ready = False
        claim_message = 'Buy weekly insurance to activate claims'
        policy_start = None
        policy_end = None
    else:
        policy_status = policy.status
        claim_ready = policy.premium_paid and policy.status == 'EXPIRED'
        claim_message = 'Ready to claim' if claim_ready else 'Claim available after policy period ends'
        policy_start = policy.start_date
        policy_end = policy.end_date

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
        'last_payout': _round(last_payout.amount) if last_payout else 0.0,
        'latest_claim_status': latest_claim.status if latest_claim else None,
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
