from sqlalchemy import Boolean, Column, Date, DateTime, Float, ForeignKey, Integer, String, func

from database.db import Base


class GigIncome(Base):
    __tablename__ = 'gig_income'

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id'), index=True, nullable=False)
    date = Column(Date, nullable=False, index=True)
    orders_completed = Column(Integer, nullable=False)
    hours_worked = Column(Float, nullable=False)
    earnings = Column(Float, nullable=False)
    earnings_per_order = Column(Float, nullable=False)
    platform = Column(String(50), nullable=False)
    disruption_type = Column(String(50), nullable=False, default='none')

    weather_condition = Column(String(20), nullable=False, default='clear')
    temperature = Column(Float, nullable=False, default=30.0)
    humidity = Column(Float, nullable=False, default=50.0)
    rainfall = Column(Float, nullable=False, default=0.0)
    wind_speed = Column(Float, nullable=False, default=5.0)

    aqi_level = Column(Integer, nullable=False, default=1)
    pm2_5 = Column(Float, nullable=False, default=10.0)
    pm10 = Column(Float, nullable=False, default=20.0)

    traffic_level = Column(String(20), nullable=False, default='LOW')
    traffic_score = Column(Float, nullable=False, default=1.0)

    peak_hours_active = Column(Float, nullable=False, default=3.0)
    off_peak_hours = Column(Float, nullable=False, default=3.0)
    expected_orders = Column(Integer, nullable=False, default=16)
    order_acceptance_rate = Column(Float, nullable=False, default=0.95)
    order_completion_rate = Column(Float, nullable=False, default=0.98)
    distance_travelled_km = Column(Float, nullable=False, default=50.0)
    avg_delivery_time_mins = Column(Float, nullable=False, default=30.0)

    earnings_per_hour = Column(Float, nullable=False, default=80.0)
    efficiency_score = Column(Float, nullable=False, default=2.5)
    loss_amount = Column(Float, nullable=False, default=0.0)
    earnings_variance = Column(Float, nullable=False, default=0.0)
    risk_score = Column(Float, nullable=False, default=0.0)

    is_weekend = Column(Boolean, nullable=False, default=False)
    is_holiday = Column(Boolean, nullable=False, default=False)
    city = Column(String(100), nullable=False, default='Chennai')

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
