from datetime import datetime
from typing import Dict
import random
import uuid

from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from models.user_model import User
from models.digilocker_request import DigiLockerRequest
from services.blockchain_service import log_verification
from utils.validators import validate_aadhaar, validate_license

MOCK_DOCUMENTS = [
    {
        'document_type': 'aadhaar',
        'document_number': '123456789012',
        'name': 'Sanju',
        'dob': '2002-01-01',
        'gender': 'Male',
        'address': 'Chennai, Tamil Nadu',
        'issued_by': 'UIDAI',
        'issued_date': '2018-06-01',
        'status': 'valid',
    },
    {
        'document_type': 'license',
        'document_number': 'TN1234567',
        'name': 'Sanju',
        'dob': '2002-01-01',
        'gender': 'Male',
        'address': 'Chennai, Tamil Nadu',
        'issued_by': 'RTO Tamil Nadu',
        'issued_date': '2023-03-14',
        'status': 'valid',
    },
    {
        'document_type': 'aadhaar',
        'document_number': '987654321098',
        'name': 'Aditi',
        'dob': '1995-09-10',
        'gender': 'Female',
        'address': 'Bengaluru, Karnataka',
        'issued_by': 'UIDAI',
        'issued_date': '2017-11-20',
        'status': 'valid',
    },
    {
        'document_type': 'license',
        'document_number': 'DL9876543210',
        'name': 'Aditi',
        'dob': '1995-09-10',
        'gender': 'Female',
        'address': 'Bengaluru, Karnataka',
        'issued_by': 'RTO Karnataka',
        'issued_date': '2021-02-01',
        'status': 'expired',
    },
    {
        'document_type': 'aadhaar',
        'document_number': '111122223333',
        'name': 'Rahul',
        'dob': '1988-12-05',
        'gender': 'Male',
        'address': 'Pune, Maharashtra',
        'issued_by': 'UIDAI',
        'issued_date': '2016-05-10',
        'status': 'invalid',
    },
    {
        'document_type': 'license',
        'document_number': 'MH1234567890123',
        'name': 'Riya',
        'dob': '1992-03-04',
        'gender': 'Female',
        'address': 'Mumbai, Maharashtra',
        'issued_by': 'RTO Maharashtra',
        'issued_date': '2024-01-10',
        'status': 'valid',
    },
]


def _mask_document(document_type: str, doc_number: str):
    if document_type == 'aadhaar' and len(doc_number) == 12 and doc_number.isdigit():
        return f"XXXX-XXXX-{doc_number[-4:]}"
    if document_type == 'license':
        mask = doc_number[:2] + '****' + doc_number[-4:]
        return mask
    return '****'


def _round(value, places=3):
    return float(round(value, places))


def create_request(db: Session, user_id: int) -> dict:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')

    request_id = str(uuid.uuid4())
    req = DigiLockerRequest(
        request_id=request_id,
        user_id=user_id,
        status='PENDING',
        provider_name='DigiLocker',
        consent_given=False,
    )
    db.add(req)
    db.commit()
    db.refresh(req)

    return {
        'request_id': req.request_id,
        'status': req.status,
        'provider_name': req.provider_name,
    }


def process_consent(db: Session, request_id: str, document_type: str, document_number: str, name: str) -> dict:
    req = db.query(DigiLockerRequest).filter(DigiLockerRequest.request_id == request_id).first()
    if not req:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Digilocker request not found')

    if req.status != 'PENDING':
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Request already processed')

    if document_type == 'aadhaar':
        if not validate_aadhaar(document_number):
            req.status = 'FAILED'
            req.failure_reason = 'Invalid Aadhaar format'
            req.verification_score = 0.1
            req.provider_name = 'DigiLocker'
            db.commit()
            return {
                'status': 'FAILED',
                'provider_name': req.provider_name,
                'verification_score': req.verification_score,
                'failure_reason': req.failure_reason,
            }
    elif document_type == 'license':
        if not validate_license(document_number):
            req.status = 'FAILED'
            req.failure_reason = 'Invalid license format'
            req.verification_score = 0.1
            req.provider_name = 'DigiLocker'
            db.commit()
            return {
                'status': 'FAILED',
                'provider_name': req.provider_name,
                'verification_score': req.verification_score,
                'failure_reason': req.failure_reason,
            }

    document = next(
        (doc for doc in MOCK_DOCUMENTS if doc['document_type'] == document_type and doc['document_number'] == document_number),
        None,
    )

    if not document or document['name'].lower() != name.lower() or document['status'] != 'valid':
        req.status = 'FAILED'
        req.failure_reason = 'Invalid document or mismatch'
        req.verification_score = 0.2
        req.provider_name = 'DigiLocker'
        req.consent_given = True
        db.commit()
        return {
            'status': 'FAILED',
            'provider_name': req.provider_name,
            'verification_score': req.verification_score,
            'failure_reason': req.failure_reason,
        }

    req.status = 'VERIFIED'
    req.consent_given = True
    req.document_type = document_type
    req.document_number_masked = _mask_document(document_type, document_number)
    req.verification_score = random.uniform(0.90, 0.99)
    req.verified_name = document['name']
    req.verified_dob = document['dob']
    req.verified_gender = document['gender']
    req.verified_address = document['address']
    req.issued_by = document['issued_by']
    req.issued_date = document['issued_date']
    req.verified_at = datetime.utcnow()

    chain_resp = log_verification(req.user_id)
    req.blockchain_txn_id = chain_resp.get('transaction_id', f"MOCK_TXN_{uuid.uuid4()}")

    user = db.query(User).filter(User.id == req.user_id).first()
    if user:
        user.is_verified = True
        user.verified_at = datetime.utcnow()

    db.commit()

    return {
        'status': 'VERIFIED',
        'provider_name': req.provider_name,
        'verification_score': _round(req.verification_score),
        'document_type': req.document_type,
        'document_number_masked': req.document_number_masked,
        'verified_profile': {
            'name': req.verified_name,
            'dob': req.verified_dob,
            'gender': req.verified_gender,
            'address': req.verified_address,
            'issued_by': req.issued_by,
            'issued_date': req.issued_date,
        },
        'blockchain_txn_id': req.blockchain_txn_id,
    }


def get_status(db: Session, user_id: int) -> dict:
    req = (
        db.query(DigiLockerRequest)
        .filter(DigiLockerRequest.user_id == user_id)
        .order_by(DigiLockerRequest.created_at.desc())
        .first()
    )
    if not req:
        return {
            'is_verified': False,
            'provider_name': 'DigiLocker',
            'status': 'NONE',
            'verified_name': None,
            'document_type': None,
            'document_number_masked': None,
            'verified_at': None,
            'verification_score': None,
            'blockchain_txn_id': None,
        }

    return {
        'is_verified': req.status == 'VERIFIED',
        'provider_name': req.provider_name,
        'status': req.status,
        'verified_name': req.verified_name,
        'document_type': req.document_type,
        'document_number_masked': req.document_number_masked,
        'verified_at': req.verified_at,
        'verification_score': req.verification_score,
        'blockchain_txn_id': req.blockchain_txn_id,
    }
