from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy.orm import Session

from services.bank_service import credit, log_transaction


def _utcnow_iso() -> str:
    return datetime.now(UTC).replace(tzinfo=None).isoformat()


def execute_instant_payout(
    *,
    db: Session,
    user_id: int,
    amount: float,
    claim_id: str,
    metadata: dict | None = None,
) -> dict:
    account = credit(db=db, user_id=user_id, amount=amount)
    transaction = log_transaction(
        db=db,
        user_id=user_id,
        transaction_type='CLAIM_PAYOUT',
        amount=amount,
        reference_id=claim_id,
        metadata={
            'claim_id': claim_id,
            'remark': f'Instant payout credited for {claim_id}',
            **(metadata or {}),
        },
    )
    return {
        'status': 'SUCCESS',
        'amount': float(round(float(amount), 2)),
        'transaction_id': transaction.reference_id,
        'timestamp': _utcnow_iso(),
        'balance': float(round(float(account.balance), 2)),
    }
