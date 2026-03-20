from typing import Union

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.digilocker_schema import (
    DigiLockerRequestSchema,
    DigiLockerRequestResponseSchema,
    DigiLockerConsentSchema,
    DigiLockerConsentFailureResponseSchema,
    DigiLockerConsentSuccessResponseSchema,
    DigiLockerStatusResponseSchema,
)
from services.digilocker_service import create_request, get_status, process_consent

router = APIRouter(prefix='/digilocker', tags=['digilocker'])


@router.post('/request', response_model=DigiLockerRequestResponseSchema, status_code=status.HTTP_201_CREATED)
def digilocker_request(payload: DigiLockerRequestSchema, db: Session = Depends(get_db)):
    record = create_request(db, payload.user_id)
    return DigiLockerRequestResponseSchema.model_validate(record).model_dump()


@router.post(
    '/consent',
    response_model=Union[DigiLockerConsentSuccessResponseSchema, DigiLockerConsentFailureResponseSchema],
)
def digilocker_consent(payload: DigiLockerConsentSchema, db: Session = Depends(get_db)):
    result = process_consent(db, payload.request_id, payload.document_type.lower(), payload.document_number, payload.name)
    if result.get('status') == 'FAILED':
        return DigiLockerConsentFailureResponseSchema(
            status='FAILED',
            reason=result.get('failure_reason', 'Invalid document or mismatch'),
        ).model_dump()
    return DigiLockerConsentSuccessResponseSchema(
        status='VERIFIED',
        name=result.get('verified_profile', {}).get('name', payload.name),
        document_type=result['document_type'],
    ).model_dump()


@router.get('/status', response_model=DigiLockerStatusResponseSchema)
def digilocker_status(user_id: int = Query(..., gt=0), db: Session = Depends(get_db)):
    return DigiLockerStatusResponseSchema.model_validate(get_status(db, user_id)).model_dump()
