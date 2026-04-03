import bcrypt
import re


PASSWORD_RULES_MESSAGE = (
    'Password must be at least 8 characters and include uppercase, lowercase, number, and special character'
)


def hash_password(password: str) -> str:
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))


def hash_otp(otp: str) -> str:
    return hash_password(otp)


def verify_otp(otp: str, hashed_otp: str) -> bool:
    return verify_password(otp, hashed_otp)


def validate_password_strength(password: str) -> bool:
    if len(password) < 8:
        return False
    checks = [
        re.search(r'[A-Z]', password),
        re.search(r'[a-z]', password),
        re.search(r'\d', password),
        re.search(r'[^A-Za-z0-9]', password),
    ]
    return all(checks)
