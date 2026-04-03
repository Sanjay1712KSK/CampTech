from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class DigiLockerRequestSchema(BaseModel):
    model_config = ConfigDict(extra='forbid')

    user_id: int = Field(..., gt=0)
    doc_type: Literal['aadhaar', 'passport']


class DigiLockerRequestResponseSchema(BaseModel):
    request_id: str
    status: Literal['PENDING']
    provider_name: str
    redirect_url: str
    oauth_state: str


class DigiLockerVerifySchema(BaseModel):
    model_config = ConfigDict(extra='forbid')

    request_id: str
    consent_code: str = Field(..., min_length=6, max_length=64)


class DigiLockerVerifyResponseSchema(BaseModel):
    status: Literal['VERIFIED']
    provider_name: str
    verified_name: str
    doc_type: Literal['aadhaar', 'passport']
    verified_at: datetime
    blockchain_txn_id: str | None = None


class DigiLockerFailureResponseSchema(BaseModel):
    status: Literal['FAILED']
    reason: str


class DigiLockerStatusResponseSchema(BaseModel):
    is_verified: bool
    provider_name: str
    status: str
    verified_name: str | None = None
    doc_type: str | None = None
    verified_at: datetime | None = None
    verification_score: float | None = None
    blockchain_txn_id: str | None = None
