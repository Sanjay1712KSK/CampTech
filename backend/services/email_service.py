import logging
import os
import smtplib
from email.message import EmailMessage
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / '.env', override=False)

logger = logging.getLogger('gig_insurance_backend.email')

SMTP_HOST = os.getenv('SMTP_HOST', 'smtp-relay.brevo.com').strip()
SMTP_PORT = int(os.getenv('SMTP_PORT', '587'))
SMTP_USER = os.getenv('SMTP_USER', '').strip()
SMTP_PASS = os.getenv('SMTP_PASS', '').strip()
SENDER_EMAIL = os.getenv('SENDER_EMAIL', SMTP_USER).strip()


def _provider_configured() -> tuple[bool, str | None]:
    if not SMTP_HOST:
        return False, 'SMTP host is not configured'
    if not SMTP_USER:
        return False, 'SMTP user is not configured'
    if not SMTP_PASS:
        return False, 'SMTP password is not configured'
    if not SENDER_EMAIL:
        return False, 'Sender email is not configured'
    return True, None


def _deliver_email(*, to_email: str, subject: str, body: str) -> tuple[bool, str | None]:
    configured, error = _provider_configured()
    if not configured:
        return False, error

    message = EmailMessage()
    message['From'] = SENDER_EMAIL
    message['To'] = to_email
    message['Subject'] = subject
    message.set_content(body)

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=20) as smtp:
            smtp.ehlo()
            smtp.starttls()
            smtp.ehlo()
            smtp.login(SMTP_USER, SMTP_PASS)
            smtp.send_message(message)
        return True, None
    except Exception as exc:  # pragma: no cover - external SMTP
        logger.exception('Brevo SMTP delivery failed for %s: %s', to_email, exc)
        return False, 'Unable to send email right now'


def send_otp_email(to_email: str, otp: str) -> tuple[bool, str | None]:
    subject = 'GigShield OTP Verification'
    body = (
        'Hello,\n\n'
        f'Your OTP is: {otp}\n\n'
        'This OTP will expire in 5 minutes.\n\n'
        'Do not share this code.\n\n'
        '* Team GigShield'
    )
    return _deliver_email(to_email=to_email, subject=subject, body=body)


def send_transactional_email(*, to_email: str, subject: str, body: str) -> tuple[bool, str | None]:
    return _deliver_email(to_email=to_email, subject=subject, body=body)
