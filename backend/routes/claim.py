from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.insurance_schema import ClaimProcessRequest, ClaimProcessResponse
from services.bank_service import credit, log_transaction
from services.blockchain_service import log_to_blockchain
from services.claim_engine import process_claim

router = APIRouter(prefix='/claim', tags=['claim'])


@router.post('/process', response_model=ClaimProcessResponse)
def process_claim_endpoint(payload: ClaimProcessRequest, db: Session = Depends(get_db)):
    result = process_claim(
        user_id=payload.user_id,
        db=db,
        lat=payload.lat,
        lon=payload.lon,
    )

    if result['status'] != 'APPROVED':
        return result

    account = credit(db=db, user_id=payload.user_id, amount=result['payout'])
    txn = log_transaction(
        db=db,
        user_id=payload.user_id,
        transaction_type='CLAIM_PAYOUT',
        amount=result['payout'],
        reference_id=result.get('claim_id'),
        metadata={'loss': result['loss'], 'fraud_score': result['fraud_score']},
    )
    chain_resp = log_to_blockchain(
        event_type='claim_payout',
        payload={
            'user_id': payload.user_id,
            'claim_id': result.get('claim_id'),
            'loss': result['loss'],
            'payout': result['payout'],
            'transaction_id': txn.reference_id,
        },
    )
    db.commit()
    db.refresh(account)

    return {
        'status': 'APPROVED',
        'loss': result['loss'],
        'payout': result['payout'],
        'fraud_score': result['fraud_score'],
        'reasons': None,
    }
