from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import relationship

from database.db import Base


class UserSettings(Base):
    __tablename__ = 'user_settings'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False, unique=True, index=True)
    ml_consent = Column(Boolean, nullable=False, default=False)
    data_sharing_consent = Column(Boolean, nullable=False, default=False)
    preferred_language = Column(String(12), nullable=True)
    notification_preferences = Column(JSON, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    user = relationship('User', back_populates='settings')


class IncomeSummary(Base):
    __tablename__ = 'income_summary'
    __table_args__ = (
        UniqueConstraint('user_id', 'summary_date', 'summary_type', name='uq_income_summary_user_date_type'),
    )

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    summary_date = Column(Date, nullable=False, index=True)
    summary_type = Column(String(20), nullable=False, default='daily', index=True)
    platform = Column(String(50), nullable=True)
    city = Column(String(100), nullable=True)
    total_income = Column(Float, nullable=False, default=0.0)
    average_income = Column(Float, nullable=False, default=0.0)
    total_hours = Column(Float, nullable=False, default=0.0)
    total_orders = Column(Integer, nullable=False, default=0)
    disruption_days = Column(Integer, nullable=False, default=0)
    summary_metadata = Column(JSON, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    user = relationship('User', back_populates='income_summaries')


class RiskSnapshot(Base):
    __tablename__ = 'risk_snapshots'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    income_summary_id = Column(Integer, ForeignKey('income_summary.id', ondelete='SET NULL'), nullable=True, index=True)
    snapshot_date = Column(Date, nullable=True, index=True)
    lat = Column(Float, nullable=False)
    lon = Column(Float, nullable=False)
    city = Column(String(100), nullable=True)
    risk_score = Column(Float, nullable=False, default=0.0)
    risk_level = Column(String(16), nullable=False, default='LOW')
    expected_income_loss_pct = Column(Integer, nullable=False, default=0)
    trigger_severity = Column(String(16), nullable=True)
    delivery_efficiency = Column(JSON, nullable=True)
    time_slot_risk = Column(JSON, nullable=True)
    predictive_risk = Column(JSON, nullable=True)
    active_triggers = Column(JSON, nullable=True)
    reasons = Column(JSON, nullable=True)
    fraud_signals = Column(JSON, nullable=True)
    adaptive_weights = Column(JSON, nullable=True)
    environment_context = Column(JSON, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    user = relationship('User', back_populates='risk_snapshots')
    income_summary = relationship('IncomeSummary')
    premium_snapshots = relationship('PremiumSnapshot', back_populates='risk_snapshot')


class PremiumSnapshot(Base):
    __tablename__ = 'premium_snapshots'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    risk_snapshot_id = Column(Integer, ForeignKey('risk_snapshots.id', ondelete='SET NULL'), nullable=True, index=True)
    policy_id = Column(Integer, ForeignKey('policies.id', ondelete='SET NULL'), nullable=True, index=True)
    baseline_income = Column(Float, nullable=False, default=0.0)
    weekly_income = Column(Float, nullable=False, default=0.0)
    weekly_premium = Column(Float, nullable=False, default=0.0)
    coverage = Column(Float, nullable=False, default=0.0)
    pricing_factor = Column(Float, nullable=False, default=0.07)
    explanation = Column(Text, nullable=True)
    pricing_metadata = Column(JSON, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    user = relationship('User', back_populates='premium_snapshots')
    risk_snapshot = relationship('RiskSnapshot', back_populates='premium_snapshots')
    policy = relationship('Policy', back_populates='premium_snapshots')


class ClaimHistory(Base):
    __tablename__ = 'claim_history'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    policy_id = Column(Integer, ForeignKey('policies.id', ondelete='SET NULL'), nullable=True, index=True)
    risk_snapshot_id = Column(Integer, ForeignKey('risk_snapshots.id', ondelete='SET NULL'), nullable=True, index=True)
    claim_reference = Column(String(64), nullable=False, unique=True, index=True)
    claim_date = Column(Date, nullable=False, index=True)
    status = Column(String(24), nullable=False, default='PENDING', index=True)
    predicted_loss = Column(Float, nullable=False, default=0.0)
    actual_loss = Column(Float, nullable=False, default=0.0)
    claimed_loss = Column(Float, nullable=False, default=0.0)
    approved_payout = Column(Float, nullable=False, default=0.0)
    fraud_score = Column(Float, nullable=True)
    trigger_snapshot = Column(JSON, nullable=True)
    reasons = Column(JSON, nullable=True)
    review_notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    user = relationship('User', back_populates='claim_history')
    policy = relationship('Policy', back_populates='claim_history')
    risk_snapshot = relationship('RiskSnapshot')


class UserBehavior(Base):
    __tablename__ = 'user_behavior'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    event_type = Column(String(50), nullable=False, index=True)
    event_value = Column(String(255), nullable=True)
    confidence_score = Column(Float, nullable=True)
    behavior_metadata = Column(JSON, nullable=True)
    observed_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    user = relationship('User', back_populates='behavior_events')


class ModelWeight(Base):
    __tablename__ = 'model_weights'

    id = Column(Integer, primary_key=True, index=True)
    model_name = Column(String(50), nullable=False, index=True)
    version = Column(String(32), nullable=False, default='v1')
    rain_weight = Column(Float, nullable=False, default=0.35)
    traffic_weight = Column(Float, nullable=False, default=0.25)
    aqi_weight = Column(Float, nullable=False, default=0.25)
    wind_weight = Column(Float, nullable=False, default=0.15)
    heat_weight = Column(Float, nullable=False, default=0.10)
    learning_rate = Column(Float, nullable=False, default=0.01)
    weight_metadata = Column(JSON, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)


class BlockchainRecord(Base):
    __tablename__ = 'blockchain_records'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True, index=True)
    policy_id = Column(Integer, ForeignKey('policies.id', ondelete='SET NULL'), nullable=True, index=True)
    claim_history_id = Column(Integer, ForeignKey('claim_history.id', ondelete='SET NULL'), nullable=True, index=True)
    digilocker_request_id = Column(Integer, ForeignKey('digilocker_requests.id', ondelete='SET NULL'), nullable=True, index=True)
    transaction_type = Column(String(50), nullable=False, index=True)
    network = Column(String(50), nullable=True)
    transaction_hash = Column(String(255), nullable=False, unique=True, index=True)
    block_number = Column(String(64), nullable=True)
    status = Column(String(24), nullable=False, default='CONFIRMED')
    payload = Column(JSON, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    user = relationship('User', back_populates='blockchain_records')
    policy = relationship('Policy')
    claim = relationship('ClaimHistory')
    digilocker_request = relationship('DigiLockerRequest')
