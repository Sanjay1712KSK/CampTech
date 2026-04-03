from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from database.db import get_db
from schemas.user_schema import (
    AvailabilityResponse,
    ConfirmAccountResponse,
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    FirstLoginOtpRequest,
    FirstLoginOtpVerifyRequest,
    LoginRequest,
    LoginResponse,
    MessageResponse,
    OnboardingStatusResponse,
    RegistrationRequest,
    RegistrationResponse,
    SendOtpRequest,
    SendOtpResponse,
    UserSessionResponse,
    UsernameSuggestionsResponse,
    VerifyOtpRequest,
    VerifyOtpResponse,
    VerifyResetOtpRequest,
    VerifyResetOtpResponse,
    ResetPasswordRequest,
    VerificationRequest,
)
from services import auth_service, verification_service

router = APIRouter(prefix='/auth', tags=['auth'])
bearer_scheme = HTTPBearer(auto_error=False)


@router.get('/check-username', response_model=AvailabilityResponse)
def check_username(username: str = Query(..., min_length=3), db: Session = Depends(get_db)):
    return auth_service.check_username_availability(db, username)


@router.get('/check-email', response_model=AvailabilityResponse)
def check_email(email: str = Query(...), db: Session = Depends(get_db)):
    return auth_service.check_email_availability(db, email)


@router.get('/suggest-usernames', response_model=UsernameSuggestionsResponse)
def suggest_usernames(username: str = Query(..., min_length=2), db: Session = Depends(get_db)):
    return {'suggestions': auth_service.suggest_usernames(db, username)}


@router.post('/signup', response_model=RegistrationResponse, status_code=status.HTTP_201_CREATED)
def signup(payload: RegistrationRequest, db: Session = Depends(get_db)):
    user = auth_service.create_user(
        db,
        email=payload.email,
        country_code=payload.country_code,
        phone_number=payload.phone_number,
        username=payload.username,
        password=payload.password,
    )
    return {
        'user_id': user.id,
        'email': user.email,
        'phone': user.phone,
        'username': user.username,
        'next_step': 'otp_verification',
        'onboarding_status': 'pending_otp',
    }


@router.post('/send-otp', response_model=SendOtpResponse)
def send_otp(payload: SendOtpRequest, db: Session = Depends(get_db)):
    return auth_service.send_otp(db, user_id=payload.user_id, purpose=payload.purpose)


@router.post('/verify-otp', response_model=VerifyOtpResponse)
def verify_otp(payload: VerifyOtpRequest, db: Session = Depends(get_db)):
    return auth_service.verify_signup_otp(db, payload.user_id, payload.email_otp, payload.phone_otp)


@router.get('/confirm', response_model=ConfirmAccountResponse)
def confirm_account(token: str = Query(..., min_length=16), db: Session = Depends(get_db)):
    return auth_service.confirm_account(db, token)


@router.get('/onboarding-status', response_model=OnboardingStatusResponse)
def onboarding_status(user_id: int = Query(..., gt=0), db: Session = Depends(get_db)):
    return auth_service.get_onboarding_status(db, user_id)


@router.post('/login', response_model=LoginResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    return auth_service.authenticate_user(db, payload.identifier or '', payload.password)


@router.post('/send-first-login-otp', response_model=SendOtpResponse)
def send_first_login_otp(payload: FirstLoginOtpRequest, db: Session = Depends(get_db)):
    return auth_service.send_first_login_otp(db, payload.challenge_token, payload.channel)


@router.post('/verify-first-login-otp', response_model=LoginResponse)
def verify_first_login_otp(payload: FirstLoginOtpVerifyRequest, db: Session = Depends(get_db)):
    return auth_service.verify_first_login_otp(db, payload.challenge_token, payload.channel, payload.otp)


@router.get('/me', response_model=UserSessionResponse)
def me(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
):
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Missing access token')
    try:
        user = auth_service.get_user_from_access_token(db, credentials.credentials)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    return auth_service.build_user_session(user)


@router.post('/forgot-password', response_model=ForgotPasswordResponse)
def forgot_password(payload: ForgotPasswordRequest, db: Session = Depends(get_db)):
    return auth_service.forgot_password(db, payload.identifier)


@router.post('/verify-reset-otp', response_model=VerifyResetOtpResponse)
def verify_reset_otp(payload: VerifyResetOtpRequest, db: Session = Depends(get_db)):
    return auth_service.verify_reset_otp(db, payload.user_id, payload.email_otp, payload.phone_otp)


@router.post('/reset-password', response_model=MessageResponse)
def reset_password(payload: ResetPasswordRequest, db: Session = Depends(get_db)):
    return auth_service.reset_password(db, payload.reset_token, payload.new_password)


@router.post('/verify-identity', response_model=MessageResponse)
def verify_identity(payload: VerificationRequest, db: Session = Depends(get_db)):
    result = verification_service.verify_identity(db, payload.user_id, payload.document_type)
    return {'message': f"{result['status']}:{result.get('doc_type', payload.document_type)}"}
