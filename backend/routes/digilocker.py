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
from utils.response import success_response, error_response

router = APIRouter(prefix='/digilocker', tags=['digilocker'])


@router.post('/request', status_code=status.HTTP_201_CREATED)
def digilocker_request(payload: DigiLockerRequestSchema, db: Session = Depends(get_db)):
    try:
        record = create_request(db, payload.user_id)
        return success_response(record)
    except Exception as exc:
        return error_response('DIGILOCKER_REQUEST_FAILED', str(exc))


@router.post('/consent')
def digilocker_consent(payload: DigiLockerConsentSchema, db: Session = Depends(get_db)):
    try:
        result = process_consent(db, payload.request_id, payload.document_type.lower(), payload.document_number, payload.name)
        if result.get('status') == 'FAILED':
            return error_response('INVALID_DOCUMENT', result.get('failure_reason', 'Invalid document or mismatch'))
        return success_response(result)
    except Exception as exc:
        return error_response('DIGILOCKER_CONSENT_FAILED', str(exc))


@router.get('/status')
def digilocker_status(user_id: int, db: Session = Depends(get_db)):
    try:
        status_data = get_status(db, user_id)
        return success_response(status_data)
    except Exception as exc:
        return error_response('DIGILOCKER_STATUS_FAILED', str(exc))
