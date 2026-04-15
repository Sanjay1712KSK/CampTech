import logging
import os
from pathlib import Path

from dotenv import load_dotenv

try:
    import mailtrap as mt
except ImportError:  # pragma: no cover - depends on local environment
    mt = None

load_dotenv(Path(__file__).resolve().parent.parent / '.env', override=False)

logger = logging.getLogger('gig_insurance_backend.notifications')

MAILTRAP_TOKEN = os.getenv('MAILTRAP_TOKEN', os.getenv('MAILTRAP_API_TOKEN', '')).strip()
MAILTRAP_SENDER_EMAIL = os.getenv('MAILTRAP_SENDER_EMAIL', 'hello@demomailtrap.co').strip()
MAILTRAP_SENDER_NAME = os.getenv('MAILTRAP_SENDER_NAME', 'Mailtrap Test').strip()
DEMO_EMAIL_REDIRECT = os.getenv(
    'MAILTRAP_DEMO_REDIRECT_EMAIL',
    os.getenv('DEMO_EMAIL_REDIRECT', 'demo-actors@demomailtrap.co'),
).strip()


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


def _is_demo_email(email: str) -> bool:
    return email.strip().lower().endswith('@gigshield.demo')


def _resolve_mailtrap_recipient(email: str) -> tuple[str, str]:
    normalized = email.strip().lower()
    if _is_demo_email(normalized):
        return DEMO_EMAIL_REDIRECT, 'sandbox_redirect'
    return normalized, 'direct'


def _deliver_mailtrap_email(*, to_email: str, subject: str, text: str, category: str) -> tuple[bool, str | None]:
    if mt is None:
        return False, 'Mailtrap package is not installed on the backend environment'
    if not MAILTRAP_TOKEN:
        return False, 'MAILTRAP_TOKEN is not configured on the backend environment'

    resolved_email, _ = _resolve_mailtrap_recipient(to_email)

    mail = mt.Mail(
        sender=mt.Address(email=MAILTRAP_SENDER_EMAIL, name=MAILTRAP_SENDER_NAME),
        to=[mt.Address(email=resolved_email)],
        subject=subject,
        text=text,
        category=category,
    )
    client = mt.MailtrapClient(token=MAILTRAP_TOKEN)
    try:
        client.send(mail)
        return True, None
    except Exception as exc:  # pragma: no cover - external network/service
        logger.exception('Mailtrap email delivery failed for %s: %s', to_email, exc)
        return False, 'Unable to send email right now'


def send_email_otp(email: str, otp: str, purpose: str) -> dict:
    if purpose == 'signup':
        subject = 'GigShield registration OTP'
        text = (
            'Welcome to GigShield.\n\n'
            f'Your registration OTP is: {otp}\n'
            'This OTP is valid for 5 minutes.\n\n'
            'If you did not start this signup, please ignore this email.'
        )
        category = 'Registration OTP'
    elif purpose == 'first_login':
        subject = 'GigShield first login verification OTP'
        text = (
            'We noticed a first-time sign in to your GigShield account.\n\n'
            f'Your verification OTP is: {otp}\n'
            'This OTP is valid for 5 minutes.\n\n'
            'If this was not you, please secure your account immediately.'
        )
        category = 'First Login OTP'
    else:
        subject = 'GigShield login recovery OTP'
        text = (
            'We received a password reset request for your GigShield account.\n\n'
            f'Your OTP is: {otp}\n'
            'This OTP is valid for 5 minutes.\n\n'
            'If this was not you, please ignore this email.'
        )
        category = 'Reset OTP'

    resolved_email, delivery_mode = _resolve_mailtrap_recipient(email)
    success, error_message = _deliver_mailtrap_email(
        to_email=email,
        subject=subject,
        text=text,
        category=category,
    )
    if success:
        logger.info('Mailtrap email OTP sent to %s [%s]', email, purpose)
    else:
        logger.warning('Mailtrap email OTP failed for %s [%s]: %s', email, purpose, error_message)
    return {
        'channel': 'email',
        'destination': _mask_email(email),
        'delivery_mode': delivery_mode,
        'redirected_to': _mask_email(resolved_email) if delivery_mode == 'sandbox_redirect' else None,
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
    app_line = (
        f'Open in the app:\n{app_confirmation_link}\n\n'
        if app_confirmation_link
        else ''
    )
    resolved_email, delivery_mode = _resolve_mailtrap_recipient(email)
    success, error_message = _deliver_mailtrap_email(
        to_email=email,
        subject='GigShield account confirmation',
        text=(
            'Your contact verification is complete.\n\n'
            'Tap the app confirmation link below to activate your GigShield account in the mobile app:\n'
            f'{app_line}'
            'Fallback web confirmation link:\n'
            f'{confirmation_link}\n\n'
            'If you did not request this, please ignore the email.'
        ),
        category='Account Confirmation',
    )
    if success:
        logger.info('Mailtrap confirmation email sent to %s', email)
    else:
        logger.warning('Mailtrap confirmation email failed for %s: %s', email, error_message)
    return {
        'channel': 'email',
        'destination': _mask_email(email),
        'delivery_mode': delivery_mode,
        'redirected_to': _mask_email(resolved_email) if delivery_mode == 'sandbox_redirect' else None,
        'status': 'sent' if success else 'failed',
        'error_message': error_message,
        'confirmation_link': confirmation_link,
        'app_confirmation_link': app_confirmation_link,
    }
