from datetime import datetime
from typing import Literal
from pydantic import BaseModel, Field, constr, model_validator


document_number_aadhaar = constr(pattern=r'^\d{12}$')
document_number_license = constr(pattern=r'^[A-Za-z0-9]{8,15}$')


class DigiLockerRequestSchema(BaseModel):
    user_id: int = Field(..., gt=0)


class DigiLockerConsentSchema(BaseModel):
    request_id: constr(pattern=r'^[0-9a-fA-F\-]{36}$')
    document_type: Literal['aadhaar', 'license']
    document_number: str
    name: str = Field(..., min_length=2)

    @model_validator(mode='after')
    def validate_document(self):
        dt = self.document_type
        dn = self.document_number
        if dt == 'aadhaar':
            if not dn.isdigit() or len(dn) != 12:
                raise ValueError('Invalid Aadhaar format')
        if dt == 'license':
            if not dn.isalnum() or not (8 <= len(dn) <= 15):
                raise ValueError('Invalid license format')
        return self


class DigiLockerRequestResponseSchema(BaseModel):
    request_id: str
    status: str
    provider_name: str


class DigiLockerConsentResponseSchema(BaseModel):
    status: str
    provider_name: str
    verification_score: float | None = None
    document_type: str | None = None
    document_number_masked: str | None = None
    verified_profile: dict | None = None
    failure_reason: str | None = None
    blockchain_txn_id: str | None = None


class DigiLockerStatusResponseSchema(BaseModel):
    is_verified: bool
    provider_name: str
    status: str
    verified_name: str | None = None
    document_type: str | None = None
    document_number_masked: str | None = None
    verified_at: datetime | None = None
    verification_score: float | None = None
    blockchain_txn_id: str | None = None

