import os
import random
import re
from datetime import UTC, datetime, timedelta

from fastapi import HTTPException, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from models.user_model import User
from models.verification import Verification
from services.notification_service import send_confirmation_email, send_email_otp, send_sms_otp
from utils.jwt import decode_token, encode_token
from utils.rate_limiter import enforce_rate_limit
from utils.security import (
    PASSWORD_RULES_MESSAGE,
    hash_otp,
    hash_password,
    validate_password_strength,
    verify_otp,
    verify_password,
)


OTP_EXPIRY_SECONDS = 5 * 60
OTP_RETRY_LIMIT = 5
ACCESS_TOKEN_EXPIRY_SECONDS = 12 * 60 * 60
CONFIRMATION_TOKEN_EXPIRY_SECONDS = 30 * 60
RESET_TOKEN_EXPIRY_SECONDS = 15 * 60
PUBLIC_BASE_URL = os.getenv('API_PUBLIC_BASE_URL', 'http://127.0.0.1:8000')


def _utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _normalize_username(username: str) -> str:
    return username.strip().lower()


def normalize_phone(country_code: str, phone_number: str) -> str:
    return f'{country_code.strip()}{phone_number.strip()}'


def _generate_otp() -> str:
    return f'{random.randint(0, 999999):06d}'


def _user_or_404(db: Session, user_id: int) -> User:
    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')
    return user


def _active_verification(db: Session, user_id: int, purpose: str, channel: str) -> Verification | None:
    return (
        db.query(Verification)
        .filter(
            Verification.user_id == int(user_id),
            Verification.type == purpose,
            Verification.channel == channel,
            Verification.is_consumed.is_(False),
        )
        .order_by(Verification.created_at.desc(), Verification.id.desc())
        .first()
    )


def _verification_types_for_purpose(purpose: str) -> tuple[str, str]:
    if purpose == 'signup':
        return ('email', 'phone')
    if purpose == 'reset':
        return ('reset', 'reset')
    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Unsupported OTP purpose')


def _mark_existing_codes_consumed(db: Session, user_id: int, purpose: str) -> None:
    email_type, phone_type = _verification_types_for_purpose(purpose)
    (
        db.query(Verification)
        .filter(
            Verification.user_id == int(user_id),
            Verification.type.in_([email_type, phone_type]),
            Verification.is_consumed.is_(False),
        )
        .update({'is_consumed': True}, synchronize_session=False)
    )


def _assert_unique_user_fields(db: Session, email: str, username: str, phone: str, ignore_user_id: int | None = None) -> None:
    query = db.query(User).filter(
        or_(
            User.email == _normalize_email(email),
            User.username == _normalize_username(username),
            User.phone == phone,
        )
    )
    if ignore_user_id is not None:
        query = query.filter(User.id != int(ignore_user_id))
    existing = query.first()
    if not existing:
        return
    if existing.email == _normalize_email(email):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='Email already registered')
    if existing.username == _normalize_username(username):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='Username already taken')
    if existing.phone == phone:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='Phone already registered')


def build_user_session(user: User) -> dict:
    return {
        'id': user.id,
        'email': user.email,
        'phone': user.phone,
        'username': user.username,
        'name': user.name,
        'is_email_verified': bool(user.is_email_verified),
        'is_phone_verified': bool(user.is_phone_verified),
        'is_account_confirmed': bool(user.is_account_confirmed),
        'is_digilocker_verified': bool(user.is_digilocker_verified),
        'has_completed_first_login_2fa': bool(user.has_completed_first_login_2fa),
        'created_at': user.created_at,
    }


def _issue_access_session(user: User) -> dict:
    token = encode_token(
        {'sub': str(user.id), 'purpose': 'access', 'username': user.username},
        expires_in_seconds=ACCESS_TOKEN_EXPIRY_SECONDS,
    )
    return {
        'requires_two_factor': False,
        'access_token': token,
        'token_type': 'bearer',
        'expires_in': ACCESS_TOKEN_EXPIRY_SECONDS,
        'user': build_user_session(user),
        'two_factor_token': None,
        'available_channels': [],
        'message': 'Login successful',
    }


def create_user(db: Session, email: str, country_code: str, phone_number: str, username: str, password: str) -> User:
    normalized_email = _normalize_email(email)
    normalized_username = _normalize_username(username)
    full_phone = normalize_phone(country_code, phone_number)

    if not validate_password_strength(password):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=PASSWORD_RULES_MESSAGE)

    _assert_unique_user_fields(db, normalized_email, normalized_username, full_phone)

    user = User(
        email=normalized_email,
        phone=full_phone,
        username=normalized_username,
        name=normalized_username,
        password_hash=hash_password(password),
        is_email_verified=False,
        is_phone_verified=False,
        is_account_confirmed=False,
        is_digilocker_verified=False,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def check_username_availability(db: Session, username: str) -> dict:
    normalized_username = _normalize_username(username)
    available = db.query(User).filter(User.username == normalized_username).first() is None
    suggestion = None if available else suggest_usernames(db, normalized_username, limit=1)[0]
    return {
        'available': available,
        'suggestion': suggestion,
        'message': 'Username is available' if available else 'Username is already taken',
    }


def check_email_availability(db: Session, email: str) -> dict:
    normalized_email = _normalize_email(email)
    available = db.query(User).filter(User.email == normalized_email).first() is None
    return {
        'available': available,
        'suggestion': None,
        'message': 'Email is available' if available else 'Email is already registered',
    }


def suggest_usernames(db: Session, username: str, limit: int = 4) -> list[str]:
    slug = re.sub(r'[^a-zA-Z0-9_.]+', '', username.strip().lower()) or 'gigworker'
    suggestions: list[str] = []
    attempt = 0
    while len(suggestions) < limit and attempt < 25:
        candidate = f'{slug}{random.randint(10, 9999)}'
        if db.query(User).filter(User.username == candidate).first() is None and candidate not in suggestions:
            suggestions.append(candidate)
        attempt += 1
    return suggestions


def send_otp(db: Session, user_id: int, purpose: str) -> dict:
    user = _user_or_404(db, user_id)
    enforce_rate_limit(f'otp-send:{purpose}:{user.id}', limit=3, window_seconds=10 * 60)

    _mark_existing_codes_consumed(db, user.id, purpose)
    email_type, phone_type = _verification_types_for_purpose(purpose)

    email_otp = _generate_otp()
    phone_otp = _generate_otp()
    expires_at = _utcnow() + timedelta(seconds=OTP_EXPIRY_SECONDS)

    email_record = Verification(
        user_id=user.id,
        otp_code=hash_otp(email_otp),
        type=email_type,
        channel='email',
        destination=user.email,
        expires_at=expires_at,
        attempts=0,
        max_attempts=OTP_RETRY_LIMIT,
    )
    phone_record = Verification(
        user_id=user.id,
        otp_code=hash_otp(phone_otp),
        type=phone_type,
        channel='phone',
        destination=user.phone,
        expires_at=expires_at,
        attempts=0,
        max_attempts=OTP_RETRY_LIMIT,
    )
    db.add_all([email_record, phone_record])
    db.commit()

    deliveries = [
        send_email_otp(user.email, email_otp, purpose),
        send_sms_otp(user.phone, phone_otp, purpose),
    ]
    return {
        'message': f'OTP sent for {purpose}',
        'purpose': purpose,
        'expires_in_seconds': OTP_EXPIRY_SECONDS,
        'retry_limit': OTP_RETRY_LIMIT,
        'deliveries': deliveries,
    }


def _validate_otp_record(db: Session, record: Verification | None, otp_value: str, channel_label: str) -> None:
    if record is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f'No active {channel_label} OTP found')
    if record.is_consumed:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f'{channel_label.title()} OTP already used')
    if record.expires_at <= _utcnow():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f'{channel_label.title()} OTP expired')
    if record.attempts >= record.max_attempts:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=f'{channel_label.title()} OTP retry limit reached')

    record.attempts += 1
    if not verify_otp(otp_value, record.otp_code):
        db.commit()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f'Invalid {channel_label} OTP')

    record.is_consumed = True


def verify_signup_otp(db: Session, user_id: int, email_otp: str, phone_otp: str) -> dict:
    user = _user_or_404(db, user_id)
    enforce_rate_limit(f'otp-verify:signup:{user.id}', limit=6, window_seconds=10 * 60)

    email_record = _active_verification(db, user.id, 'email', 'email')
    phone_record = _active_verification(db, user.id, 'phone', 'phone')

    _validate_otp_record(db, email_record, email_otp, 'email')
    _validate_otp_record(db, phone_record, phone_otp, 'phone')

    user.is_email_verified = True
    user.is_phone_verified = True
    confirmation_token = encode_token(
        {'sub': str(user.id), 'purpose': 'account_confirmation'},
        expires_in_seconds=CONFIRMATION_TOKEN_EXPIRY_SECONDS,
    )
    confirmation_link = f'{PUBLIC_BASE_URL}/auth/confirm?token={confirmation_token}'
    send_confirmation_email(user.email, confirmation_link)
    db.commit()

    return {
        'email_verified': True,
        'phone_verified': True,
        'confirmation_token': confirmation_token,
        'confirmation_link': confirmation_link,
        'next_step': 'account_confirmation',
    }


def confirm_account(db: Session, token: str) -> dict:
    try:
        payload = decode_token(token, expected_purpose='account_confirmation')
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    user = _user_or_404(db, int(payload['sub']))
    if not user.is_email_verified or not user.is_phone_verified:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='OTP verification is incomplete')

    user.is_account_confirmed = True
    db.commit()

    return {
        'account_confirmed': True,
        'next_step': 'digilocker_verification',
        'message': 'Account confirmed successfully',
    }


def _resolve_identifier_query(db: Session, identifier: str) -> User | None:
    normalized_identifier = identifier.strip()
    normalized_email = normalized_identifier.lower()
    normalized_username = normalized_identifier.lower()
    return (
        db.query(User)
        .filter(
            or_(
                User.email == normalized_email,
                User.username == normalized_username,
                User.phone == normalized_identifier,
            )
        )
        .first()
    )


def authenticate_user(db: Session, identifier: str, password: str) -> dict:
    enforce_rate_limit(f'login:{identifier.strip().lower()}', limit=10, window_seconds=10 * 60)
    user = _resolve_identifier_query(db, identifier)
    if not user or not verify_password(password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid credentials')
    if not user.is_account_confirmed:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Account confirmation is still pending')
    if not user.is_digilocker_verified:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Complete DigiLocker verification before login')
    if not user.has_completed_first_login_2fa:
        challenge_token = encode_token(
            {'sub': str(user.id), 'purpose': 'first_login_challenge'},
            expires_in_seconds=OTP_EXPIRY_SECONDS,
        )
        return {
            'requires_two_factor': True,
            'access_token': None,
            'token_type': None,
            'expires_in': None,
            'user': None,
            'two_factor_token': challenge_token,
            'available_channels': ['email', 'phone'],
            'message': 'Choose email or phone for first-time login verification',
        }

    return _issue_access_session(user)


def send_first_login_otp(db: Session, challenge_token: str, channel: str) -> dict:
    try:
        payload = decode_token(challenge_token, expected_purpose='first_login_challenge')
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    user = _user_or_404(db, int(payload['sub']))
    if user.has_completed_first_login_2fa:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='First-login verification is already complete')
    if channel not in {'email', 'phone'}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Unsupported verification channel')

    enforce_rate_limit(f'otp-send:first_login:{channel}:{user.id}', limit=3, window_seconds=10 * 60)
    (
        db.query(Verification)
        .filter(
            Verification.user_id == int(user.id),
            Verification.type == 'first_login',
            Verification.channel == channel,
            Verification.is_consumed.is_(False),
        )
        .update({'is_consumed': True}, synchronize_session=False)
    )

    otp = _generate_otp()
    record = Verification(
        user_id=user.id,
        otp_code=hash_otp(otp),
        type='first_login',
        channel=channel,
        destination=user.email if channel == 'email' else user.phone,
        expires_at=_utcnow() + timedelta(seconds=OTP_EXPIRY_SECONDS),
        attempts=0,
        max_attempts=OTP_RETRY_LIMIT,
    )
    db.add(record)
    db.commit()

    delivery = (
        send_email_otp(user.email, otp, 'first_login')
        if channel == 'email'
        else send_sms_otp(user.phone, otp, 'first_login')
    )
    return {
        'message': 'First-login OTP sent',
        'purpose': 'signup',
        'expires_in_seconds': OTP_EXPIRY_SECONDS,
        'retry_limit': OTP_RETRY_LIMIT,
        'deliveries': [delivery],
    }


def verify_first_login_otp(db: Session, challenge_token: str, channel: str, otp: str) -> dict:
    try:
        payload = decode_token(challenge_token, expected_purpose='first_login_challenge')
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    user = _user_or_404(db, int(payload['sub']))
    if user.has_completed_first_login_2fa:
        return _issue_access_session(user)

    enforce_rate_limit(f'otp-verify:first_login:{channel}:{user.id}', limit=6, window_seconds=10 * 60)
    record = _active_verification(db, user.id, 'first_login', channel)
    _validate_otp_record(db, record, otp, channel)
    user.has_completed_first_login_2fa = True
    db.commit()
    return _issue_access_session(user)


def forgot_password(db: Session, identifier: str) -> dict:
    user = _resolve_identifier_query(db, identifier)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Account not found')
    otp_response = send_otp(db, user.id, purpose='reset')
    return {
        'user_id': user.id,
        'message': 'Reset OTP sent to your email and phone',
        'expires_in_seconds': otp_response['expires_in_seconds'],
        'deliveries': otp_response['deliveries'],
    }


def verify_reset_otp(db: Session, user_id: int, email_otp: str, phone_otp: str) -> dict:
    user = _user_or_404(db, user_id)
    enforce_rate_limit(f'otp-verify:reset:{user.id}', limit=6, window_seconds=10 * 60)

    email_record = _active_verification(db, user.id, 'reset', 'email')
    phone_record = _active_verification(db, user.id, 'reset', 'phone')

    _validate_otp_record(db, email_record, email_otp, 'email')
    _validate_otp_record(db, phone_record, phone_otp, 'phone')
    db.commit()

    reset_token = encode_token(
        {'sub': str(user.id), 'purpose': 'password_reset'},
        expires_in_seconds=RESET_TOKEN_EXPIRY_SECONDS,
    )
    return {
        'reset_token': reset_token,
        'next_step': 'reset_password',
        'message': 'OTP verified. You can set a new password now.',
    }


def reset_password(db: Session, reset_token: str, new_password: str) -> dict:
    if not validate_password_strength(new_password):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=PASSWORD_RULES_MESSAGE)

    try:
        payload = decode_token(reset_token, expected_purpose='password_reset')
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    user = _user_or_404(db, int(payload['sub']))
    user.password_hash = hash_password(new_password)
    db.commit()
    return {'message': 'Password reset successful'}


def get_user_from_access_token(db: Session, token: str) -> User:
    payload = decode_token(token, expected_purpose='access')
    return _user_or_404(db, int(payload['sub']))
