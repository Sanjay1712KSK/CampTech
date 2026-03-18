from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.digilocker_schema import (
    DigiLockerRequestSchema,
    DigiLockerRequestResponseSchema,
    DigiLockerConsentSchema,
    DigiLockerConsentResponseSchema,
    DigiLockerStatusResponseSchema,
)
from services.digilocker_service import create_request, process_consent, get_status

router = APIRouter(prefix='/digilocker', tags=['digilocker'])


@router.post('/request', response_model=DigiLockerRequestResponseSchema, status_code=status.HTTP_201_CREATED)
def digilocker_request(payload: DigiLockerRequestSchema, db: Session = Depends(get_db)):
    record = create_request(db, payload.user_id)
    return record


@router.post('/consent', response_model=DigiLockerConsentResponseSchema)
def digilocker_consent(payload: DigiLockerConsentSchema, db: Session = Depends(get_db)):
    result = process_consent(db, payload.request_id, payload.document_type.lower(), payload.document_number, payload.name)
    return result


@router.get('/status', response_model=DigiLockerStatusResponseSchema)
def digilocker_status(user_id: int, db: Session = Depends(get_db)):
    return get_status(db, user_id)
