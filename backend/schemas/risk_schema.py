from pydantic import BaseModel, Field

from schemas.environment_schema import EnvironmentResponse


class RiskFactorsResponse(BaseModel):
    weather_risk: float = Field(..., ge=0.0, le=1.0)
    aqi_risk: float = Field(..., ge=0.0, le=1.0)
    traffic_risk: float = Field(..., ge=0.0, le=1.0)
    time_risk: float = Field(..., ge=0.0, le=1.0)


class RiskResponse(BaseModel):
    risk_score: float = Field(..., ge=0.0, le=1.0)
    risk_level: str
    risk_factors: RiskFactorsResponse
    recommendation: str


class GigContextResponse(BaseModel):
    earnings_today: float
    orders_completed: int


class RiskEnvelopeResponse(BaseModel):
    environment: EnvironmentResponse
    risk: RiskResponse
    gig_context: GigContextResponse | None = None
