from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from models.user_model import User
from services.blockchain_service import log_verification


def verify_identity(db: Session, user_id: int, document_type: str) -> dict:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='User not found')

    if user.is_verified:
        return {'status': 'already_verified'}

    # Mock verification process (no real DigiLocker call)
    if document_type not in ['aadhaar', 'license']:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Invalid document type')

    user.is_verified = True
    db.commit()
    db.refresh(user)

    # Blockchain log
    chain_resp = log_verification(user_id)

    return {
        'status': 'verified',
        'user_id': user.id,
        'document_type': document_type,
        'blockchain': chain_resp,
    }
