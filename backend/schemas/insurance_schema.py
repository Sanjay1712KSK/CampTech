from datetime import date

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
    weekly_premium: float
    coverage: float
    risk_score: float = Field(..., ge=0.0, le=1.0)
    risk: dict
    explanation: str


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


class BankTransactionItemResponse(BaseModel):
    transaction_id: str
    transaction_type: str
    amount: float
    status: str
    reference_id: str | None = None
    remark: str | None = None
    created_at: str


class BankTransactionHistoryResponse(BaseModel):
    user_id: int
    transactions: list[BankTransactionItemResponse]


class ClaimProcessRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    user_id: int = Field(..., gt=0)
    lat: float = Field(..., ge=-90.0, le=90.0)
    lon: float = Field(..., ge=-180.0, le=180.0)
    device_id: str | None = Field(default=None, min_length=3, max_length=255)


class ClaimProcessResponse(BaseModel):
    claim_status: str
    reason: str | None = None
    status: str
    expected_income: float | None = None
    actual_income: float | None = None
    weekly_loss: float | None = None
    loss: float | None = None
    payout: float | None = None
    predicted_loss: float | None = None
    fraud_score: float | None = Field(default=None, ge=0.0, le=1.0)
    confidence: float | str | None = None
    reasons: list[str] | None = None
    blockchain_txn_id: str | None = None
    payout_blockchain_txn_id: str | None = None
    fraud: dict | None = None
    transaction: dict | None = None
    blockchain: dict | None = None
    environment: dict | None = None
    risk: dict | None = None
    premium: dict | None = None
    policy: dict | None = None
    gig: dict | None = None
    location_status: dict | None = None
    claim_id: str | None = None
    fraud_log_id: int | None = None


class ClaimPayoutRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    user_id: int = Field(..., gt=0)
    amount: float = Field(..., gt=0)
    claim_id: str | None = None


class SupportChatRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    user_id: int = Field(..., gt=0)
    query: str = Field(..., min_length=2, max_length=500)


class SupportChatResponse(BaseModel):
    response: str


class InsuranceSummaryResponse(BaseModel):
    user_id: int
    bank_linked: bool
    account_number_masked: str | None = None
    ifsc: str | None = None
    balance: float | None = None
    total_paid: float
    total_claimed: float
    policy_status: str
    policy_start: date | None = None
    policy_end: date | None = None
    claim_ready: bool
    claim_message: str
    last_payout: float
    latest_claim_status: str | None = None
    recent_remarks: list[str] = []
