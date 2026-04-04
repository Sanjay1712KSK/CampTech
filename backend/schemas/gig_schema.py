from datetime import date

from pydantic import BaseModel, ConfigDict, Field, model_validator


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
    worker_id: str | None = Field(default=None, min_length=3, max_length=64)
    partner_id: str | None = Field(default=None, min_length=3, max_length=64)

    @model_validator(mode='after')
    def normalize_worker_id(self):
        resolved_worker_id = (self.worker_id or self.partner_id or '').strip()
        if not resolved_worker_id:
            raise ValueError('worker_id is required')
        self.worker_id = resolved_worker_id
        self.partner_id = resolved_worker_id
        return self


class GigConnectResponse(BaseModel):
    message: str
    income_generated: bool
    status: str
    user_id: int
    platform: str
    worker_id: str
    partner_id: str
    generated: int


class GigStatusResponse(BaseModel):
    connected: bool
    platform: str | None = None
    worker_id: str | None = None


class GigIncomeHistoryItem(BaseModel):
    date: date
    income: float
    hours: float
    earnings: float
    orders_completed: int
    hours_worked: float
    platform: str
    disruption_type: str


class BaselineIncomeResponse(BaseModel):
    baseline_income: float
    baseline_daily_income: float


class TodayIncomeResponse(BaseModel):
    date: date
    income: float
    hours: float
    earnings: float
    orders_completed: int
    hours_worked: float
    disruption_type: str
    platform: str


class WeeklySummaryDay(BaseModel):
    date: date
    earnings: float
    weather_condition: str
    traffic_level: str
    disruption_type: str


class WeeklySummaryResponse(BaseModel):
    total_income: float
    average_daily: float
    avg_daily_earnings: float
    total_orders: int
    total_hours: float
    total_loss_amount: float
    avg_risk_score: float
    best_day: WeeklySummaryDay | None
    worst_day: WeeklySummaryDay | None
