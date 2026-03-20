from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class CoordinatesQuery(BaseModel):
    model_config = ConfigDict(extra='forbid')

    lat: float = Field(..., ge=-90, le=90, examples=[13.0827])
    lon: float = Field(..., ge=-180, le=180, examples=[80.2707])


class WeatherResponse(BaseModel):
    temperature: float
    humidity: float
    wind_speed: float
    rainfall: float


class AqiResponse(BaseModel):
    aqi: int
    pm2_5: float
    pm10: float


class TrafficResponse(BaseModel):
    traffic_score: float
    traffic_level: Literal['LOW', 'MEDIUM', 'HIGH']


class ContextResponse(BaseModel):
    hour: int
    day_type: Literal['weekday', 'weekend']


class EnvironmentResponse(BaseModel):
    weather: WeatherResponse
    aqi: AqiResponse
    traffic: TrafficResponse
    context: ContextResponse
