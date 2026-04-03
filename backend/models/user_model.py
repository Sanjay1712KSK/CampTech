from sqlalchemy import Boolean, Column, DateTime, Integer, String, func

from database.db import Base


class User(Base):
    __tablename__ = 'users'

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    phone = Column(String(50), unique=True, nullable=False, index=True)
    username = Column(String(64), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    password_hash = Column(String(255), nullable=False)
    is_email_verified = Column(Boolean, default=False, nullable=False)
    is_phone_verified = Column(Boolean, default=False, nullable=False)
    is_account_confirmed = Column(Boolean, default=False, nullable=False)
    is_digilocker_verified = Column(Boolean, default=False, nullable=False)
    has_completed_first_login_2fa = Column(Boolean, default=False, nullable=False)
    verified_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    @property
    def is_verified(self) -> bool:
        return bool(self.is_digilocker_verified)
