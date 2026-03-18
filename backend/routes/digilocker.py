from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.digilocker_schema import (
    DigiLockerRequestSchema,
    DigiLockerRequestResponseSchema,
    DigiLockerConsentSchema,
    DigiLockerResponseSchema,
)
from services.digilocker_service import create_request, process_consent

router = APIRouter(prefix='/digilocker', tags=['digilocker'])


@router.post('/request', response_model=DigiLockerRequestResponseSchema, status_code=status.HTTP_201_CREATED)
def digilocker_request(payload: DigiLockerRequestSchema, db: Session = Depends(get_db)):
    record = create_request(db, payload.user_id)
    return {
        'request_id': record['request_id'],
        'status': record['status']
    }


@router.post('/consent', response_model=DigiLockerResponseSchema)
def digilocker_consent(payload: DigiLockerConsentSchema, db: Session = Depends(get_db)):
    result = process_consent(db, payload.request_id, payload.document_type.lower(), payload.document_number, payload.name)
    if result['status'] == 'FAILED':
        return {
            'status': 'FAILED',
            'name': None,
            'document_type': None,
            'verified_data': None,
            'reason': result['reason']
        }

    return {
        'status': 'VERIFIED',
        'name': result['name'],
        'document_type': result['document_type'],
        'verified_data': result['verified_data'],
        'reason': None
    }
