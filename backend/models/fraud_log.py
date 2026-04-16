from sqlalchemy import JSON, Column, DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import relationship

from database.db import Base


class FraudLog(Base):
    __tablename__ = 'fraud_logs'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    claim_history_id = Column(Integer, ForeignKey('claim_history.id', ondelete='SET NULL'), nullable=True, index=True)
    claim_reference = Column(String(64), nullable=True, index=True)
    fraud_score = Column(Float, nullable=False, default=0.0)
    decision = Column(String(24), nullable=False, default='APPROVED', index=True)
    confidence = Column(String(16), nullable=True)
    fraud_types = Column(JSON, nullable=True)
    explanation = Column(Text, nullable=True)
    signals = Column(JSON, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)

    user = relationship('User', back_populates='fraud_logs')
    claim_history = relationship('ClaimHistory')
