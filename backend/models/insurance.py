from sqlalchemy import Boolean, Column, Date, DateTime, Float, Integer, String, Text, func

from database.db import Base


class Policy(Base):
    __tablename__ = 'policies'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True, nullable=False)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    premium_paid = Column(Boolean, nullable=False, default=False)
    status = Column(String(32), nullable=False, default='ACTIVE')
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class Claim(Base):
    __tablename__ = 'claims'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True, nullable=False)
    week = Column(String(32), nullable=False)
    loss = Column(Float, nullable=False, default=0.0)
    payout = Column(Float, nullable=False, default=0.0)
    fraud_score = Column(Float, nullable=False, default=0.0)
    status = Column(String(32), nullable=False, default='PENDING')
    reasons_json = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
