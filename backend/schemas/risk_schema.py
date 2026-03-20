from pydantic import BaseModel, Field


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


class RiskEnvelopeResponse(BaseModel):
    environment: dict
    risk: RiskResponse
    gig_context: dict | None = None
