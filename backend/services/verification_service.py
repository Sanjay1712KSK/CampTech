from sqlalchemy.orm import Session

from services.digilocker_service import create_request, verify_request


def verify_identity(db: Session, user_id: int, document_type: str) -> dict:
    request = create_request(db, user_id=user_id, doc_type=document_type)
    return verify_request(db, request_id=request['request_id'], consent_code=request['oauth_state'])
