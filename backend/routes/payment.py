from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.insurance_schema import InsuranceSummaryResponse, LinkBankRequest, LinkBankResponse, PayPremiumRequest, PaymentResponse
from services.bank_service import debit, insurance_summary, link_account, log_transaction
from services.blockchain_service import log_to_blockchain
from services.policy_service import create_policy, get_latest_policy

router = APIRouter(prefix='/payment', tags=['payment'])


@router.get('/summary', response_model=InsuranceSummaryResponse)
def payment_summary_endpoint(user_id: int = Query(..., gt=0), db: Session = Depends(get_db)):
    return insurance_summary(db=db, user_id=user_id)


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
    latest_policy = get_latest_policy(user_id=payload.user_id, db=db)
    if latest_policy is not None and latest_policy.premium_paid and latest_policy.status == 'ACTIVE':
        summary = insurance_summary(db=db, user_id=payload.user_id)
        return {
            'status': 'SUCCESS',
            'user_id': payload.user_id,
            'amount': 0.0,
            'balance': float(summary['balance'] or 0.0),
            'transaction_id': f'policy_{latest_policy.id}',
            'blockchain_txn_id': None,
        }

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
