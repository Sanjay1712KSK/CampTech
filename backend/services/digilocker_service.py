from datetime import datetime
from typing import Dict
import uuid

from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from models.user_model import User
from services.blockchain_service import log_verification
from utils.validators import validate_aadhaar, validate_license

# In-memory request store for demo purposes
DIGILOCKER_REQUEST_STORE: Dict[str, dict] = {}

MOCK_DOCUMENTS = [
    {'aadhaar': '123456789012', 'name': 'Sanju', 'dob': '2002-01-01'},
    {'license': 'TN1234567', 'name': 'Sanju'}
]


def create_request(db: Session, user_id: int) -> dict:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')

    request_id = str(uuid.uuid4())
    record = {
        'request_id': request_id,
        'user_id': user_id,
        'status': 'PENDING',
        'created_at': datetime.utcnow().isoformat() + 'Z',
        'updated_at': datetime.utcnow().isoformat() + 'Z'
    }
    DIGILOCKER_REQUEST_STORE[request_id] = record
    return record


def process_consent(db: Session, request_id: str, document_type: str, document_number: str, name: str) -> dict:
    req = DIGILOCKER_REQUEST_STORE.get(request_id)
    if not req:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Digilocker request not found')

    if req['status'] != 'PENDING':
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Request already processed')

    # Format validation
    if document_type == 'aadhaar':
        if not validate_aadhaar(document_number):
            req['status'] = 'FAILED'
            return {'status': 'FAILED', 'reason': 'Invalid Aadhaar format'}
    elif document_type == 'license':
        if not validate_license(document_number):
            req['status'] = 'FAILED'
            return {'status': 'FAILED', 'reason': 'Invalid license format'}

    # Document existence and name match
    match = None
    for doc in MOCK_DOCUMENTS:
        if document_type == 'aadhaar' and doc.get('aadhaar') == document_number:
            match = doc
            break
        if document_type == 'license' and doc.get('license') == document_number:
            match = doc
            break

    if not match or match.get('name', '').strip().lower() != name.strip().lower():
        req['status'] = 'FAILED'
        req['updated_at'] = datetime.utcnow().isoformat() + 'Z'
        return {'status': 'FAILED', 'reason': 'Invalid document or mismatch'}

    # Mark verified
    req['status'] = 'VERIFIED'
    req['updated_at'] = datetime.utcnow().isoformat() + 'Z'

    user = db.query(User).filter(User.id == req['user_id']).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')

    user.is_verified = True
    user.verified_at = datetime.utcnow()
    db.commit()
    db.refresh(user)

    blockchain_resp = log_verification(user.id)

    verified_data = {}
    if document_type == 'aadhaar':
        verified_data['dob'] = match.get('dob')

    return {
        'status': 'VERIFIED',
        'name': user.name,
        'document_type': document_type,
        'verified_data': verified_data,
        'reason': None,
        'blockchain_log': blockchain_resp
    }
