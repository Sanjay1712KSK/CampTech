from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.user_schema import UserCreate, UserLogin, VerificationRequest, UserResponse
from services import auth_service, verification_service
from utils.response import success_response, error_response

router = APIRouter(prefix='/auth', tags=['auth'])


@router.post('/signup', status_code=status.HTTP_201_CREATED)
def signup(user_payload: UserCreate, db: Session = Depends(get_db)):
    try:
        user = auth_service.create_user(db, user_payload.name, user_payload.email, user_payload.phone, user_payload.password)
        return success_response(UserResponse.from_orm(user).dict())
    except Exception as exc:
        return error_response('AUTH_SIGNUP_ERROR', str(exc))


@router.post('/login')
def login(login_payload: UserLogin, db: Session = Depends(get_db)):
    try:
        user = auth_service.authenticate_user(db, login_payload.email, login_payload.password)
        return success_response(UserResponse.from_orm(user).dict())
    except Exception as exc:
        return error_response('AUTH_LOGIN_FAILED', str(exc))


@router.post('/verify-identity')
def verify_identity(verify_payload: VerificationRequest, db: Session = Depends(get_db)):
    try:
        result = verification_service.verify_identity(db, verify_payload.user_id, verify_payload.document_type)
        return success_response(result)
    except Exception as exc:
        return error_response('VERIFY_IDENTITY_FAILED', str(exc))
