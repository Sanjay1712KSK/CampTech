from sqlalchemy import Column, DateTime, Float, Integer, func

from database.db import Base


class AdaptiveRiskWeight(Base):
    __tablename__ = 'adaptive_risk_weights'

    id = Column(Integer, primary_key=True, index=True)
    rain_weight = Column(Float, nullable=False, default=0.35)
    traffic_weight = Column(Float, nullable=False, default=0.25)
    aqi_weight = Column(Float, nullable=False, default=0.25)
    wind_weight = Column(Float, nullable=False, default=0.15)
    sample_count = Column(Integer, nullable=False, default=0)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
