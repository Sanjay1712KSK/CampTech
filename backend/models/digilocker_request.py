from sqlalchemy import Column, Integer, String, Boolean, Float, DateTime, func

from database.db import Base


class DigiLockerRequest(Base):
    __tablename__ = 'digilocker_requests'

    id = Column(Integer, primary_key=True, index=True)
    request_id = Column(String(64), unique=True, index=True, nullable=False)
    user_id = Column(Integer, index=True, nullable=False)
    status = Column(String(20), nullable=False, default='PENDING')
    document_type = Column(String(20), nullable=True)
    document_number_masked = Column(String(50), nullable=True)
    consent_given = Column(Boolean, nullable=False, default=False)
    verification_score = Column(Float, nullable=True)
    failure_reason = Column(String(255), nullable=True)
    provider_name = Column(String(50), nullable=False, default='DigiLocker')
    verified_name = Column(String(255), nullable=True)
    verified_dob = Column(String(20), nullable=True)
    verified_gender = Column(String(20), nullable=True)
    verified_address = Column(String(255), nullable=True)
    issued_by = Column(String(255), nullable=True)
    issued_date = Column(String(20), nullable=True)
    verified_at = Column(DateTime(timezone=True), nullable=True)
    blockchain_txn_id = Column(String(255), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
