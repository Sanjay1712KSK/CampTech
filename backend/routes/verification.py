from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from database.db import get_db
from services.verification_service import create_digilocker_request, process_consent
from schemas.verification_schema import (
    DigiLockerRequest,
    DigiLockerRequestResponse,
    ConsentRequest,
    VerificationResponse,
)

router = APIRouter(prefix='/digilocker', tags=['digilocker'])


@router.post('/request', response_model=DigiLockerRequestResponse, status_code=status.HTTP_201_CREATED)
def create_request(payload: DigiLockerRequest, db: Session = Depends(get_db)):
    record = create_digilocker_request(db, payload.user_id)
    return {
        'request_id': record['request_id'],
        'status': record['status'],
        'redirect_url': record['redirect_url']
    }


@router.post('/consent', response_model=VerificationResponse)
def consent_user(payload: ConsentRequest, db: Session = Depends(get_db)):
    result = process_consent(
        db,
        payload.request_id,
        payload.document_type.lower(),
        payload.document_number,
        payload.name,
    )

    if result['status'] == 'FAILED':
        return {
            'status': 'FAILED',
            'reason': result.get('reason', 'Invalid document or mismatch')
        }

    return {
        'status': 'VERIFIED',
        'user_name': result.get('user_name'),
        'document_type': result.get('document_type'),
        'verified_data': result.get('verified_data'),
        'reason': None
    }
