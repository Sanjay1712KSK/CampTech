import logging

from fastapi import HTTPException, status

try:
    import mailtrap as mt
except ImportError:  # pragma: no cover - depends on local environment
    mt = None

logger = logging.getLogger('gig_insurance_backend.notifications')

MAILTRAP_TOKEN = '60dd0cc51ffb85ec041d1ece8a75df28'
MAILTRAP_SENDER_EMAIL = 'hello@demomailtrap.co'
MAILTRAP_SENDER_NAME = 'Mailtrap Test'


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


def _deliver_mailtrap_email(*, to_email: str, subject: str, text: str, category: str) -> None:
    if mt is None:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail='Mailtrap package is not installed on the backend environment',
        )

    mail = mt.Mail(
        sender=mt.Address(email=MAILTRAP_SENDER_EMAIL, name=MAILTRAP_SENDER_NAME),
        to=[mt.Address(email=to_email)],
        subject=subject,
        text=text,
        category=category,
    )
    client = mt.MailtrapClient(token=MAILTRAP_TOKEN)
    try:
        client.send(mail)
    except Exception as exc:  # pragma: no cover - external network/service
        logger.exception('Mailtrap email delivery failed for %s: %s', to_email, exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail='Unable to send email OTP right now',
        ) from exc


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
    else:
        subject = 'GigShield login recovery OTP'
        text = (
            'We received a password reset request for your GigShield account.\n\n'
            f'Your OTP is: {otp}\n'
            'This OTP is valid for 5 minutes.\n\n'
            'If this was not you, please ignore this email.'
        )
        category = 'Reset OTP'

    _deliver_mailtrap_email(
        to_email=email,
        subject=subject,
        text=text,
        category=category,
    )
    logger.info('Mailtrap email OTP sent to %s [%s]', email, purpose)
    return {
        'channel': 'email',
        'destination': _mask_email(email),
        'mock_otp': None,
    }


def send_sms_otp(phone: str, otp: str, purpose: str) -> dict:
    logger.info('Mock SMS OTP for %s [%s]: %s', phone, purpose, otp)
    return {
        'channel': 'phone',
        'destination': _mask_phone(phone),
        'mock_otp': otp,
    }


def send_confirmation_email(email: str, confirmation_link: str) -> dict:
    _deliver_mailtrap_email(
        to_email=email,
        subject='GigShield account confirmation',
        text=(
            'Your contact verification is complete.\n\n'
            'Click the confirmation link below to activate your GigShield account:\n'
            f'{confirmation_link}\n\n'
            'If you did not request this, please ignore the email.'
        ),
        category='Account Confirmation',
    )
    logger.info('Mailtrap confirmation email sent to %s', email)
    return {
        'channel': 'email',
        'destination': _mask_email(email),
        'confirmation_link': confirmation_link,
    }
