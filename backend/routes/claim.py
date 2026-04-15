from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.insurance_schema import ClaimPayoutRequest, ClaimProcessRequest, ClaimProcessResponse, PaymentResponse
from services.claim_engine import process_claim
from services.payout_service import execute_instant_payout
from services.blockchain_service import record_payout

router = APIRouter(prefix='/claim', tags=['claim'])


@router.post('/process', response_model=ClaimProcessResponse)
def process_claim_endpoint(payload: ClaimProcessRequest, db: Session = Depends(get_db)):
    return process_claim(
        user_id=payload.user_id,
        db=db,
        lat=payload.lat,
        lon=payload.lon,
        device_id=payload.device_id,
    )


@router.post('/payout', response_model=PaymentResponse)
def payout_claim_endpoint(payload: ClaimPayoutRequest, db: Session = Depends(get_db)):
    txn = execute_instant_payout(
        db=db,
        user_id=payload.user_id,
        amount=payload.amount,
        claim_id=payload.claim_id or f'manual_claim_{payload.user_id}',
        metadata={'manual': True},
    )
    payout_resp = record_payout(
        claim_id=payload.claim_id or txn['transaction_id'],
        amount=payload.amount,
        user_id=payload.user_id,
        db=db,
    )
    db.commit()
    return {
        'status': 'SUCCESS',
        'user_id': payload.user_id,
        'amount': float(payload.amount),
        'balance': float(txn['balance']),
        'transaction_id': txn['transaction_id'],
        'blockchain_txn_id': payout_resp.get('tx_hash') or payout_resp.get('transaction_id'),
    }
