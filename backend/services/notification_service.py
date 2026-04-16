import logging
from pathlib import Path

from dotenv import load_dotenv

from services.email_service import send_otp_email, send_transactional_email

load_dotenv(Path(__file__).resolve().parent.parent / '.env', override=False)

logger = logging.getLogger('gig_insurance_backend.notifications')


def _mask_email(email: str) -> str:
    local, _, domain = email.partition('@')
    if len(local) <= 2:
        masked_local = f'{local[:1]}*'
    else:
        masked_local = f'{local[:2]}***'
    return f'{masked_local}@{domain}'


def _mask_phone(phone: str) -> str:
    if len(phone) <= 4:
        return '*' * len(phone)
    return f"{phone[:3]}***{phone[-3:]}"


def send_email_otp(email: str, otp: str, purpose: str) -> dict:
    success, error_message = send_otp_email(email, otp)
    if success:
        logger.info('Brevo SMTP email OTP sent to %s [%s]', email, purpose)
    else:
        logger.warning('Brevo SMTP email OTP failed for %s [%s]: %s', email, purpose, error_message)
    return {
        'channel': 'email',
        'destination': _mask_email(email),
        'delivery_mode': 'smtp',
        'redirected_to': None,
        'status': 'sent' if success else 'failed',
        'error_message': error_message,
        'mock_otp': None,
    }


def send_sms_otp(phone: str, otp: str, purpose: str) -> dict:
    logger.info('Mock SMS OTP for %s [%s]: %s', phone, purpose, otp)
    return {
        'channel': 'phone',
        'destination': _mask_phone(phone),
        'status': 'sent',
        'error_message': None,
        'mock_otp': otp,
    }


def send_confirmation_email(email: str, confirmation_link: str, app_confirmation_link: str | None = None) -> dict:
    app_line = f'Open in the app:\n{app_confirmation_link}\n\n' if app_confirmation_link else ''
    subject = 'GigShield account confirmation'
    body = (
        'Your contact verification is complete.\n\n'
        'Tap the app confirmation link below to activate your GigShield account in the mobile app:\n'
        f'{app_line}'
        'Fallback web confirmation link:\n'
        f'{confirmation_link}\n\n'
        'If you did not request this, please ignore the email.'
    )
    success, error_message = send_transactional_email(
        to_email=email,
        subject=subject,
        body=body,
    )
    if success:
        logger.info('Brevo SMTP confirmation email sent to %s', email)
    else:
        logger.warning('Brevo SMTP confirmation email failed for %s: %s', email, error_message)
    return {
        'channel': 'email',
        'destination': _mask_email(email),
        'delivery_mode': 'smtp',
        'redirected_to': None,
        'status': 'sent' if success else 'failed',
        'error_message': error_message,
        'confirmation_link': confirmation_link,
        'app_confirmation_link': app_confirmation_link,
    }
