from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.insurance_schema import LinkBankRequest, LinkBankResponse, PayPremiumRequest, PaymentResponse
from services.bank_service import debit, link_account, log_transaction
from services.blockchain_service import log_to_blockchain
from services.policy_service import create_policy

router = APIRouter(prefix='/payment', tags=['payment'])


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


@router.post('/pay-premium', response_model=PaymentResponse)
def pay_premium_endpoint(payload: PayPremiumRequest, db: Session = Depends(get_db)):
    account = debit(db=db, user_id=payload.user_id, amount=payload.amount)
    policy = create_policy(user_id=payload.user_id, db=db)
    txn = log_transaction(
        db=db,
        user_id=payload.user_id,
        transaction_type='PREMIUM_PAYMENT',
        amount=payload.amount,
        metadata={'amount': payload.amount, 'policy_id': policy.id},
    )
    chain_resp = log_to_blockchain(
        event_type='premium_payment',
        payload={
            'user_id': payload.user_id,
            'amount': payload.amount,
            'policy_id': policy.id,
            'policy_end_date': policy.end_date.isoformat(),
            'transaction_id': txn.reference_id,
        },
    )
    db.commit()
    db.refresh(account)
    return {
        'status': 'SUCCESS',
        'user_id': payload.user_id,
        'amount': float(payload.amount),
        'balance': float(account.balance),
        'transaction_id': txn.reference_id,
        'blockchain_txn_id': chain_resp.get('transaction_id'),
    }
