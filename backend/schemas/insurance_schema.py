from pydantic import BaseModel, ConfigDict, Field


class LinkBankRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    user_id: int = Field(..., gt=0)
    account_number: str = Field(..., min_length=8, max_length=32)
    ifsc: str = Field(..., min_length=4, max_length=16)


class LinkBankResponse(BaseModel):
    status: str
    user_id: int
    balance: float


class PremiumCalculationResponse(BaseModel):
    baseline: float
    weekly_income: float
    risk_score: float = Field(..., ge=0.0, le=1.0)
    weekly_premium: float


class PayPremiumRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    user_id: int = Field(..., gt=0)
    amount: float = Field(..., gt=0)


class PaymentResponse(BaseModel):
    status: str
    user_id: int
    amount: float
    balance: float
    transaction_id: str
    blockchain_txn_id: str | None = None


class ClaimProcessRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    user_id: int = Field(..., gt=0)
    lat: float = Field(..., ge=-90.0, le=90.0)
    lon: float = Field(..., ge=-180.0, le=180.0)


class ClaimProcessResponse(BaseModel):
    status: str
    loss: float | None = None
    payout: float | None = None
    fraud_score: float | None = Field(default=None, ge=0.0, le=1.0)
    reasons: list[str] | None = None
