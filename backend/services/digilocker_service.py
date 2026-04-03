import json
import random
import uuid
from datetime import UTC, datetime
from pathlib import Path

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from models.digilocker_request import DigiLockerRequest
from models.user_model import User
from services.blockchain_service import log_verification


PROVIDER_NAME = 'DigiLocker'
MOCK_DATASET_PATH = Path(__file__).resolve().parent.parent / 'data' / 'digilocker_mock_documents.json'


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _mock_verified_name(user: User) -> str:
    return (user.name or user.username).replace('_', ' ').title()


def _mock_document_mask(doc_type: str) -> str:
    if doc_type == 'aadhaar':
        suffix = random.randint(1000, 9999)
        return f'XXXX-XXXX-{suffix}'
    suffix = random.randint(1000, 9999)
    return f'P******{suffix}'


def refresh_mock_documents() -> list[dict]:
    if not MOCK_DATASET_PATH.exists():
        return []
    try:
        payload = json.loads(MOCK_DATASET_PATH.read_text(encoding='utf-8'))
    except (OSError, json.JSONDecodeError):
        return []
    return payload if isinstance(payload, list) else []


def create_request(db: Session, user_id: int, doc_type: str) -> dict:
    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')

    request_id = str(uuid.uuid4())
    oauth_state = uuid.uuid4().hex[:12].upper()
    redirect_url = f'https://mock.digilocker.local/authorize?request_id={request_id}&state={oauth_state}'

    record = DigiLockerRequest(
        request_id=request_id,
        user_id=user.id,
        doc_type=doc_type,
        status='PENDING',
        provider_name=PROVIDER_NAME,
        redirect_url=redirect_url,
        oauth_state=oauth_state,
        consent_granted=False,
    )
    db.add(record)
    db.commit()
    db.refresh(record)

    return {
        'request_id': record.request_id,
        'status': record.status,
        'provider_name': record.provider_name,
        'redirect_url': record.redirect_url,
        'oauth_state': record.oauth_state,
    }


def verify_request(db: Session, request_id: str, consent_code: str) -> dict:
    record = db.query(DigiLockerRequest).filter(DigiLockerRequest.request_id == request_id).first()
    if not record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='DigiLocker request not found')
    if record.status != 'PENDING':
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Request already processed')
    if record.oauth_state != consent_code.strip().upper():
        record.status = 'FAILED'
        record.failure_reason = 'Invalid DigiLocker consent code'
        db.commit()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Invalid DigiLocker consent code')

    user = db.query(User).filter(User.id == record.user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')

    verified_name = _mock_verified_name(user)
    verified_at = _utcnow()
    blockchain = log_verification(user.id)

    record.status = 'VERIFIED'
    record.consent_granted = True
    record.document_number_masked = _mock_document_mask(record.doc_type or 'aadhaar')
    record.verification_score = 0.97
    record.verified_name = verified_name
    record.verified_dob = '1995-01-01'
    record.verified_gender = 'Not Specified'
    record.verified_address = 'India'
    record.issued_by = 'Govt. of India'
    record.issued_date = '2024-01-01'
    record.verified_at = verified_at
    record.verified_payload_json = json.dumps(
        {
            'doc_type': record.doc_type,
            'verified_name': verified_name,
            'document_number_masked': record.document_number_masked,
        }
    )
    record.blockchain_txn_id = blockchain.get('transaction_id')

    user.is_digilocker_verified = True
    user.verified_at = verified_at

    db.commit()

    return {
        'status': 'VERIFIED',
        'provider_name': record.provider_name,
        'verified_name': verified_name,
        'doc_type': record.doc_type,
        'verified_at': verified_at,
        'blockchain_txn_id': record.blockchain_txn_id,
    }


def get_status(db: Session, user_id: int) -> dict:
    record = (
        db.query(DigiLockerRequest)
        .filter(DigiLockerRequest.user_id == int(user_id))
        .order_by(DigiLockerRequest.created_at.desc(), DigiLockerRequest.id.desc())
        .first()
    )
    if not record:
        return {
            'is_verified': False,
            'provider_name': PROVIDER_NAME,
            'status': 'NOT_STARTED',
            'verified_name': None,
            'doc_type': None,
            'verified_at': None,
            'verification_score': None,
            'blockchain_txn_id': None,
        }

    return {
        'is_verified': record.status == 'VERIFIED',
        'provider_name': record.provider_name,
        'status': record.status,
        'verified_name': record.verified_name,
        'doc_type': record.doc_type,
        'verified_at': record.verified_at,
        'verification_score': record.verification_score,
        'blockchain_txn_id': record.blockchain_txn_id,
    }
