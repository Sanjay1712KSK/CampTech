from typing import Literal

from pydantic import BaseModel, Field

from schemas.environment_schema import EnvironmentResponse


class RiskFactorsResponse(BaseModel):
    rain_risk: float = Field(..., ge=0.0, le=1.0)
    traffic_risk: float = Field(..., ge=0.0, le=1.0)
    aqi_risk: float = Field(..., ge=0.0, le=1.0)
    wind_risk: float = Field(..., ge=0.0, le=1.0)


class DeliveryEfficiencyResponse(BaseModel):
    score: float = Field(..., ge=0.0, le=1.0)
    drop: str
    drop_percentage: str
    normal_deliveries_per_hour: float
    estimated_current: float
    delivery_capacity: float
    working_hours_factor: float


class FraudSignalsResponse(BaseModel):
    location_match: bool
    environment_match: bool


class PredictiveRiskResponse(BaseModel):
    next_6hr_risk: float = Field(..., ge=0.0, le=1.0)
    trend: Literal['increasing', 'decreasing', 'stable']


class GigContextResponse(BaseModel):
    earnings_today: float
    orders_completed: int


class RiskResponse(BaseModel):
    risk_score: float = Field(..., ge=0.0, le=1.0)
    risk_level: Literal['LOW', 'MEDIUM', 'HIGH']
    expected_income_loss: str
    delivery_efficiency: DeliveryEfficiencyResponse
    hyper_local_risk: float
    hyper_local_analysis: dict
    time_slot_risk: dict[str, Literal['LOW', 'MEDIUM', 'HIGH']]
    predictive_risk: PredictiveRiskResponse
    active_triggers: list[str]
    trigger_severity: Literal['LOW', 'MEDIUM', 'HIGH']
    fraud_signals: FraudSignalsResponse
    reasons: list[str]
    risk_factors: RiskFactorsResponse
    adaptive_weights: dict[str, float]
    recommendation: str


class RiskEnvelopeResponse(BaseModel):
    risk_score: float = Field(..., ge=0.0, le=1.0)
    risk_level: Literal['LOW', 'MEDIUM', 'HIGH']
    expected_income_loss: str
    delivery_efficiency: DeliveryEfficiencyResponse
    hyper_local_risk: float
    hyper_local_analysis: dict
    time_slot_risk: dict[str, Literal['LOW', 'MEDIUM', 'HIGH']]
    predictive_risk: PredictiveRiskResponse
    active_triggers: list[str]
    trigger_severity: Literal['LOW', 'MEDIUM', 'HIGH']
    fraud_signals: FraudSignalsResponse
    reasons: list[str]
    risk_factors: RiskFactorsResponse
    adaptive_weights: dict[str, float]
    recommendation: str
    environment: EnvironmentResponse
    gig_context: GigContextResponse | None = None
