from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class CoordinatesQuery(BaseModel):
    model_config = ConfigDict(extra='forbid')

    lat: float = Field(..., ge=-90, le=90, examples=[13.0827])
    lon: float = Field(..., ge=-180, le=180, examples=[80.2707])
    user_id: int | None = Field(default=None, ge=1)


class WeatherHourlyPoint(BaseModel):
    time: str
    hour: int
    temperature: float
    humidity: float
    wind_speed: float
    rain_estimate: float


class WeatherResponse(BaseModel):
    temperature: float
    humidity: float
    wind_speed: float
    rainfall: float
    rain_estimate: float
    hourly: list[WeatherHourlyPoint] = []


class AqiResponse(BaseModel):
    aqi: int
    aqi_index: float
    pm2_5: float
    pm10: float


class TrafficResponse(BaseModel):
    traffic_score: float
    traffic_index: float
    traffic_level: Literal['LOW', 'MEDIUM', 'HIGH']
    route_duration_seconds: float
    free_flow_duration_seconds: float


class ContextResponse(BaseModel):
    hour: int
    day_type: Literal['weekday', 'weekend']


class EnvironmentSnapshotResponse(BaseModel):
    temperature: float
    wind_speed: float
    humidity: float
    rain_estimate: float
    aqi: float
    traffic_index: float


class HyperLocalAnalysisResponse(BaseModel):
    hyper_local_risk: float
    insight: str
    baseline_snapshot: EnvironmentSnapshotResponse
    source: str


class PredictiveRiskResponse(BaseModel):
    next_6hr_risk: float
    trend: Literal['increasing', 'decreasing', 'stable']


class EnvironmentResponse(BaseModel):
    weather: WeatherResponse
    aqi: AqiResponse
    traffic: TrafficResponse
    context: ContextResponse
    snapshot: EnvironmentSnapshotResponse
    hyper_local_analysis: HyperLocalAnalysisResponse
    time_slot_risk: dict[str, Literal['LOW', 'MEDIUM', 'HIGH']]
    predictive_risk: PredictiveRiskResponse
    hourly_forecast: list[dict]
