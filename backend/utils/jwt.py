import base64
import hashlib
import hmac
import json
import os
import time


JWT_SECRET = os.getenv('JWT_SECRET', 'gig-insurance-demo-secret')
JWT_ISSUER = os.getenv('JWT_ISSUER', 'gig_insurance_backend')


def _b64encode(payload: bytes) -> str:
    return base64.urlsafe_b64encode(payload).rstrip(b'=').decode('utf-8')


def _b64decode(payload: str) -> bytes:
    padding = '=' * (-len(payload) % 4)
    return base64.urlsafe_b64decode(f'{payload}{padding}'.encode('utf-8'))


def encode_token(claims: dict, expires_in_seconds: int) -> str:
    now = int(time.time())
    header = {'alg': 'HS256', 'typ': 'JWT'}
    payload = {
        **claims,
        'iat': now,
        'exp': now + int(expires_in_seconds),
        'iss': JWT_ISSUER,
    }
    header_segment = _b64encode(json.dumps(header, separators=(',', ':')).encode('utf-8'))
    payload_segment = _b64encode(json.dumps(payload, separators=(',', ':')).encode('utf-8'))
    signing_input = f'{header_segment}.{payload_segment}'.encode('utf-8')
    signature = hmac.new(JWT_SECRET.encode('utf-8'), signing_input, hashlib.sha256).digest()
    return f'{header_segment}.{payload_segment}.{_b64encode(signature)}'


def decode_token(token: str, expected_purpose: str | None = None) -> dict:
    try:
        header_segment, payload_segment, signature_segment = token.split('.')
    except ValueError as exc:
        raise ValueError('Invalid token format') from exc

    signing_input = f'{header_segment}.{payload_segment}'.encode('utf-8')
    expected_signature = hmac.new(JWT_SECRET.encode('utf-8'), signing_input, hashlib.sha256).digest()
    actual_signature = _b64decode(signature_segment)
    if not hmac.compare_digest(expected_signature, actual_signature):
        raise ValueError('Invalid token signature')

    payload = json.loads(_b64decode(payload_segment).decode('utf-8'))
    now = int(time.time())
    if int(payload.get('exp', 0)) < now:
        raise ValueError('Token expired')
    if payload.get('iss') != JWT_ISSUER:
        raise ValueError('Invalid token issuer')
    if expected_purpose is not None and payload.get('purpose') != expected_purpose:
        raise ValueError('Invalid token purpose')
    return payload
