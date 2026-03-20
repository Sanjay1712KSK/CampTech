from datetime import date
from pydantic import BaseModel, Field, ConfigDict


class GigIncomeRecord(BaseModel):
    date: date
    orders_completed: int
    hours_worked: float
    earnings: float
    earnings_per_order: float
    platform: str
    disruption_type: str
    weather_condition: str
    temperature: float
    humidity: float
    rainfall: float
    wind_speed: float
    aqi_level: int
    pm2_5: float
    pm10: float
    traffic_level: str
    traffic_score: float
    peak_hours_active: float
    off_peak_hours: float
    expected_orders: int
    order_acceptance_rate: float
    order_completion_rate: float
    distance_travelled_km: float
    avg_delivery_time_mins: float
    earnings_per_hour: float
    efficiency_score: float
    loss_amount: float
    earnings_variance: float
    risk_score: float
    is_weekend: bool
    is_holiday: bool
    city: str


class GenerateGigDataRequest(BaseModel):
    model_config = ConfigDict(
        extra='forbid',
        json_schema_extra={
            'example': {
                'user_id': 1,
                'days': 30,
            }
        }
    )

    user_id: int = Field(..., gt=0)
    days: int = Field(..., ge=1, le=90)


class GenerateGigDataResponse(BaseModel):
    generated: int
    data: list[GigIncomeRecord]


class GigConnectRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    user_id: int = Field(..., gt=0)
    platform: str = Field(..., min_length=3, max_length=20)
    partner_id: str = Field(..., min_length=3, max_length=64)


class GigConnectResponse(BaseModel):
    status: str
    user_id: int
    platform: str
    partner_id: str
    generated: int


class GigIncomeHistoryItem(BaseModel):
    date: date
    orders_completed: int
    hours_worked: float
    earnings: float
    platform: str
    disruption_type: str


class BaselineIncomeResponse(BaseModel):
    baseline_daily_income: float


class TodayIncomeResponse(BaseModel):
    earnings: float
    orders_completed: int
    hours_worked: float
    disruption_type: str


class WeeklySummaryDay(BaseModel):
    date: date
    earnings: float
    weather_condition: str
    traffic_level: str
    disruption_type: str


class WeeklySummaryResponse(BaseModel):
    avg_daily_earnings: float
    total_orders: int
    total_hours: float
    total_loss_amount: float
    avg_risk_score: float
    best_day: WeeklySummaryDay | None
    worst_day: WeeklySummaryDay | None
