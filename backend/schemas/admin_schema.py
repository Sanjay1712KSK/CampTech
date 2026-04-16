from pydantic import BaseModel, ConfigDict, EmailStr, Field


class AdminLoginRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    email: EmailStr
    password: str = Field(..., min_length=3)


class AdminLoginResponse(BaseModel):
    token: str
    role: str


class AdminOverviewResponse(BaseModel):
    total_users: int
    active_policies: int
    total_claims: int
    total_payouts: float
    total_premiums: float
    loss_ratio: float


class FraudTypeItem(BaseModel):
    type: str
    count: int


class AdminFraudStatsResponse(BaseModel):
    fraud_rate: float
    flagged_claims: int
    rejected_claims: int
    top_fraud_types: list[FraudTypeItem]


class AdminClaimsStatsResponse(BaseModel):
    approved: int
    rejected: int
    flagged: int
    avg_payout: float
    avg_loss: float


class AdminRiskStatsResponse(BaseModel):
    high_risk_users: int
    avg_risk_score: float
    top_triggers: list[str]


class AdminFinancialsResponse(BaseModel):
    total_premiums: float
    total_payouts: float
    profit: float


class AdminPredictionsResponse(BaseModel):
    next_week_claims: int
    expected_payout: float
    risk_trend: str
    insight: str


class AdminPayoutsResponse(BaseModel):
    total_payouts: float
    avg_payout: float
    payout_success_rate: float
