from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from datetime import datetime
import uuid

from models.user_model import User
from services.blockchain_service import log_verification

# In-memory DigiLocker request storage. In production this would be in DB
DIGILOCKER_REQUESTS: dict[str, dict] = {}

MOCK_DOCUMENTS = [
    {
        'aadhaar': '123456789012',
        'name': 'Sanju',
        'dob': '2002-01-01',
        'status': 'valid'
    },
    {
        'license': 'TN1234567',
        'name': 'Sanju',
        'status': 'valid'
    }
]


def verify_identity(db: Session, user_id: int, document_type: str) -> dict:
    # Keep compatibility with existing auth path
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')

    if user.is_verified:
        return {'status': 'already_verified'}

    if document_type not in ['aadhaar', 'license']:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Invalid document type')

    user.is_verified = True
    db.commit()
    db.refresh(user)
    chain_resp = log_verification(user_id)

    return {
        'status': 'verified',
        'user_id': user.id,
        'document_type': document_type,
        'blockchain': chain_resp,
    }


def create_digilocker_request(db: Session, user_id: int) -> dict:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')

    request_id = str(uuid.uuid4())
    DIGILOCKER_REQUESTS[request_id] = {
        'request_id': request_id,
        'user_id': user_id,
        'status': 'PENDING',
        'created_at': datetime.utcnow().isoformat() + 'Z',
        'redirect_url': f'/digilocker/consent/{request_id}'
    }
    return DIGILOCKER_REQUESTS[request_id]


def process_consent(db: Session, request_id: str, document_type: str, document_number: str, name: str) -> dict:
    request_scope = DIGILOCKER_REQUESTS.get(request_id)
    if not request_scope:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Digilocker request not found')

    if request_scope['status'] != 'PENDING':
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Request already processed')

    user = db.query(User).filter(User.id == request_scope['user_id']).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')

    if document_type == 'aadhaar':
        if len(document_number) != 12 or not document_number.isdigit():
            return {'status': 'FAILED', 'reason': 'Invalid Aadhaar format'}
    else:
        if document_type == 'license':
            if not document_number.isalnum() or not (7 <= len(document_number) <= 16):
                return {'status': 'FAILED', 'reason': 'Invalid license format'}
    
    match = None
    for doc in MOCK_DOCUMENTS:
        if document_type == 'aadhaar' and doc.get('aadhaar') == document_number:
            match = doc
            break
        if document_type == 'license' and doc.get('license') == document_number:
            match = doc
            break

    if not match:
        request_scope['status'] = 'FAILED'
        return {'status': 'FAILED', 'reason': 'Invalid document or mismatch'}

    if match['name'].lower() != name.strip().lower() or match.get('status') != 'valid':
        request_scope['status'] = 'FAILED'
        return {'status': 'FAILED', 'reason': 'Invalid document or mismatch'}

    # Document is verified
    request_scope['status'] = 'VERIFIED'
    user.is_verified = True
    db.commit()
    db.refresh(user)

    chain_resp = log_verification(user.id)

    verified_data = {}
    if document_type == 'aadhaar':
        verified_data['dob'] = match.get('dob')

    return {
        'status': 'VERIFIED',
        'user_name': user.name,
        'document_type': document_type,
        'verified_data': verified_data,
        'blockchain_log': chain_resp
    }
