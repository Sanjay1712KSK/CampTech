from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.insurance_schema import ClaimPayoutRequest, ClaimProcessRequest, ClaimProcessResponse, PaymentResponse
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
            'remark': f"Claim payout credited for {result.get('claim_id')}",
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
        'claim_status': 'APPROVED',
        'reason': result.get('reason'),
        'status': 'APPROVED',
        'expected_income': result.get('expected_income'),
        'actual_income': result.get('actual_income'),
        'weekly_loss': result['weekly_loss'],
        'loss': result['loss'],
        'payout': result['payout'],
        'predicted_loss': result.get('predicted_loss'),
        'fraud_score': result['fraud_score'],
        'confidence': result.get('confidence'),
        'reasons': result.get('reasons'),
    }


@router.post('/payout', response_model=PaymentResponse)
def payout_claim_endpoint(payload: ClaimPayoutRequest, db: Session = Depends(get_db)):
    account = credit(db=db, user_id=payload.user_id, amount=payload.amount)
    txn = log_transaction(
        db=db,
        user_id=payload.user_id,
        transaction_type='MANUAL_CLAIM_PAYOUT',
        amount=payload.amount,
        reference_id=payload.claim_id,
        metadata={
            'claim_id': payload.claim_id,
            'remark': f'Manual claim payout credited for {payload.claim_id or "claim"}',
        },
    )
    chain_resp = log_to_blockchain(
        event_type='claim_payout',
        payload={
            'user_id': payload.user_id,
            'amount': payload.amount,
            'claim_id': payload.claim_id,
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
