import random
from datetime import UTC, datetime, timedelta

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from models.verification import Verification
from utils.security import hash_otp, verify_otp


OTP_EXPIRY_SECONDS = 5 * 60
OTP_RETRY_LIMIT = 5


def _utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def generate_otp() -> str:
    return f'{random.randint(0, 999999):06d}'


def store_otp(
    db: Session,
    *,
    user_id: int,
    email: str,
    otp: str,
    otp_type: str = 'email',
    channel: str = 'email',
) -> Verification:
    (
        db.query(Verification)
        .filter(
            Verification.user_id == int(user_id),
            Verification.type == otp_type,
            Verification.channel == channel,
            Verification.is_consumed.is_(False),
        )
        .update({'is_consumed': True}, synchronize_session=False)
    )

    record = Verification(
        user_id=int(user_id),
        otp_code=hash_otp(otp),
        type=otp_type,
        channel=channel,
        destination=email,
        expires_at=_utcnow() + timedelta(seconds=OTP_EXPIRY_SECONDS),
        attempts=0,
        max_attempts=OTP_RETRY_LIMIT,
    )
    db.add(record)
    db.flush()
    return record


def verify_stored_otp(db: Session, *, record: Verification | None, otp: str, channel_label: str) -> None:
    if record is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f'No active {channel_label} OTP found')
    if record.is_consumed:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f'{channel_label.title()} OTP already used')
    if record.expires_at <= _utcnow():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f'{channel_label.title()} OTP expired')
    if record.attempts >= record.max_attempts:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=f'{channel_label.title()} OTP retry limit reached')

    record.attempts += 1
    if not verify_otp(otp, record.otp_code):
        db.commit()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f'Invalid {channel_label} OTP')

    record.is_consumed = True
