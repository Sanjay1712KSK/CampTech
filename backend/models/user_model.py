from sqlalchemy import Boolean, Column, DateTime, Float, Integer, String, func
from sqlalchemy.orm import relationship

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
    current_device_id = Column(String(255), nullable=True)
    session_version = Column(Integer, nullable=False, default=1)
    device_switch_count = Column(Integer, nullable=False, default=0)
    last_known_lat = Column(Float, nullable=True)
    last_known_lon = Column(Float, nullable=True)
    last_location_at = Column(DateTime(timezone=True), nullable=True)
    active_city = Column(String(100), nullable=True)
    verified_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    profile = relationship('Profile', back_populates='user', uselist=False)
    verifications = relationship('Verification', back_populates='user', cascade='all, delete-orphan')
    gig_accounts = relationship('GigAccount', back_populates='user', cascade='all, delete-orphan')
    gig_incomes = relationship('GigIncome', back_populates='user', cascade='all, delete-orphan')
    digilocker_requests = relationship('DigiLockerRequest', back_populates='user', cascade='all, delete-orphan')
    policies = relationship('Policy', back_populates='user', cascade='all, delete-orphan')
    claims = relationship('Claim', back_populates='user', cascade='all, delete-orphan')
    bank_account = relationship('BankAccount', back_populates='user', uselist=False)
    bank_transactions = relationship('BankTransaction', back_populates='user', cascade='all, delete-orphan')
    settings = relationship('UserSettings', back_populates='user', uselist=False, cascade='all, delete-orphan')
    income_summaries = relationship('IncomeSummary', back_populates='user', cascade='all, delete-orphan')
    risk_snapshots = relationship('RiskSnapshot', back_populates='user', cascade='all, delete-orphan')
    premium_snapshots = relationship('PremiumSnapshot', back_populates='user', cascade='all, delete-orphan')
    claim_history = relationship('ClaimHistory', back_populates='user', cascade='all, delete-orphan')
    behavior_events = relationship('UserBehavior', back_populates='user', cascade='all, delete-orphan')
    blockchain_records = relationship('BlockchainRecord', back_populates='user')

    @property
    def is_verified(self) -> bool:
        return bool(self.is_digilocker_verified)
