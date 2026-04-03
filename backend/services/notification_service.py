import logging


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
    logger.info('Mock email OTP for %s [%s]: %s', email, purpose, otp)
    return {
        'channel': 'email',
        'destination': _mask_email(email),
        'mock_otp': otp,
    }


def send_sms_otp(phone: str, otp: str, purpose: str) -> dict:
    logger.info('Mock SMS OTP for %s [%s]: %s', phone, purpose, otp)
    return {
        'channel': 'phone',
        'destination': _mask_phone(phone),
        'mock_otp': otp,
    }


def send_confirmation_email(email: str, confirmation_link: str) -> dict:
    logger.info('Mock confirmation email for %s: %s', email, confirmation_link)
    return {
        'channel': 'email',
        'destination': _mask_email(email),
        'confirmation_link': confirmation_link,
    }
