from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.user_schema import UserCreate, UserLogin, VerificationRequest, UserResponse
from services import auth_service, verification_service

router = APIRouter(prefix='/auth', tags=['auth'])


@router.post('/signup', response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def signup(user_payload: UserCreate, db: Session = Depends(get_db)):
    user = auth_service.create_user(db, user_payload.name, user_payload.email, user_payload.phone, user_payload.password)
    return UserResponse.model_validate(user).model_dump()


@router.post('/login', response_model=UserResponse)
def login(login_payload: UserLogin, db: Session = Depends(get_db)):
    user = auth_service.authenticate_user(db, login_payload.email, login_payload.password)
    return UserResponse.model_validate(user).model_dump()


@router.post('/verify-identity')
def verify_identity(verify_payload: VerificationRequest, db: Session = Depends(get_db)):
    return verification_service.verify_identity(db, verify_payload.user_id, verify_payload.document_type)
