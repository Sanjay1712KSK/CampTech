from sqlalchemy import Boolean, Column, DateTime, Integer, String, func

from database.db import Base


class Verification(Base):
    __tablename__ = 'verifications'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False, index=True)
    otp_code = Column(String(255), nullable=False)
    type = Column(String(32), nullable=False, index=True)
    channel = Column(String(32), nullable=False, index=True)
    destination = Column(String(255), nullable=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    attempts = Column(Integer, nullable=False, default=0)
    max_attempts = Column(Integer, nullable=False, default=5)
    is_consumed = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
