from sqlalchemy import Column, DateTime, Float, Integer, func

from database.db import Base


class EnvironmentSnapshot(Base):
    __tablename__ = 'environment_snapshots'

    id = Column(Integer, primary_key=True, index=True)
    bucket_lat = Column(Float, nullable=False, index=True)
    bucket_lon = Column(Float, nullable=False, index=True)
    temperature = Column(Float, nullable=False, default=0.0)
    wind_speed = Column(Float, nullable=False, default=0.0)
    humidity = Column(Float, nullable=False, default=0.0)
    rain_estimate = Column(Float, nullable=False, default=0.0)
    aqi = Column(Float, nullable=False, default=0.0)
    traffic_index = Column(Float, nullable=False, default=1.0)
    observed_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)
