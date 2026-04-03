from typing import Union

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.digilocker_schema import (
    DigiLockerFailureResponseSchema,
    DigiLockerRequestResponseSchema,
    DigiLockerRequestSchema,
    DigiLockerStatusResponseSchema,
    DigiLockerVerifyResponseSchema,
    DigiLockerVerifySchema,
)
from services.digilocker_service import create_request, get_status, verify_request

router = APIRouter(prefix='/digilocker', tags=['digilocker'])


@router.post('/request', response_model=DigiLockerRequestResponseSchema, status_code=status.HTTP_201_CREATED)
def digilocker_request(payload: DigiLockerRequestSchema, db: Session = Depends(get_db)):
    return create_request(db, payload.user_id, payload.doc_type)


@router.post('/verify', response_model=Union[DigiLockerVerifyResponseSchema, DigiLockerFailureResponseSchema])
def digilocker_verify(payload: DigiLockerVerifySchema, db: Session = Depends(get_db)):
    return verify_request(db, payload.request_id, payload.consent_code)


@router.post('/consent', response_model=Union[DigiLockerVerifyResponseSchema, DigiLockerFailureResponseSchema])
def digilocker_consent(payload: DigiLockerVerifySchema, db: Session = Depends(get_db)):
    return verify_request(db, payload.request_id, payload.consent_code)


@router.get('/status', response_model=DigiLockerStatusResponseSchema)
def digilocker_status(user_id: int = Query(..., gt=0), db: Session = Depends(get_db)):
    return get_status(db, user_id)
