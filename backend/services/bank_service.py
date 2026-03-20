import json
import uuid

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from models.bank_account import BankAccount, BankTransaction
from models.user_model import User


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
