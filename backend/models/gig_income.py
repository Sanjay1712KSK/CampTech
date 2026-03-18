from sqlalchemy import Column, Integer, String, Date, Float, DateTime, func

from database.db import Base


class GigIncome(Base):
    __tablename__ = 'gig_income'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True, nullable=False)
    date = Column(Date, nullable=False, index=True)
    orders_completed = Column(Integer, nullable=False)
    hours_worked = Column(Float, nullable=False)
    earnings = Column(Float, nullable=False)
    earnings_per_order = Column(Float, nullable=False)
    platform = Column(String(50), nullable=False)
    disruption_type = Column(String(50), nullable=False, default='none')
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
