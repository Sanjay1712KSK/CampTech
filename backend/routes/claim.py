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

    request_chain_resp = log_to_blockchain(
        event_type='claim_request',
        payload={
            'user_id': payload.user_id,
            'claim_id': result.get('claim_id'),
            'status': result['status'],
            'fraud_score': result.get('fraud_score'),
            'lat': payload.lat,
            'lon': payload.lon,
        },
    )

    if result['status'] != 'APPROVED':
        db.commit()
        return result

    account = credit(db=db, user_id=payload.user_id, amount=result['payout'])
    txn = log_transaction(
        db=db,
        user_id=payload.user_id,
        transaction_type='CLAIM_PAYOUT',
        amount=result['payout'],
        reference_id=result.get('claim_id'),
        metadata={
            'weekly_loss': result['weekly_loss'],
            'fraud_score': result['fraud_score'],
            'claim_request_txn_id': request_chain_resp.get('transaction_id'),
        },
    )
    chain_resp = log_to_blockchain(
        event_type='claim_payout',
        payload={
            'user_id': payload.user_id,
            'claim_id': result.get('claim_id'),
            'weekly_loss': result['weekly_loss'],
            'payout': result['payout'],
            'fraud_score': result['fraud_score'],
            'transaction_id': txn.reference_id,
        },
    )
    db.commit()
    db.refresh(account)

    return {
        'status': 'APPROVED',
        'weekly_loss': result['weekly_loss'],
        'loss': result['loss'],
        'payout': result['payout'],
        'fraud_score': result['fraud_score'],
        'reasons': None,
    }
