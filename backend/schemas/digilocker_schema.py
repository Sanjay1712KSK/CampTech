from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, constr, model_validator


RequestId = constr(pattern=r'^[0-9a-fA-F\-]{36}$')
NameField = constr(min_length=2, strip_whitespace=True)


document_number_aadhaar = constr(pattern=r'^\d{12}$')
document_number_license = constr(pattern=r'^[A-Za-z0-9]{8,15}$')


class DigiLockerRequestSchema(BaseModel):
    model_config = ConfigDict(extra='forbid')

    user_id: int = Field(..., gt=0)


class DigiLockerConsentSchema(BaseModel):
    model_config = ConfigDict(extra='forbid')

    request_id: RequestId
    document_type: Literal['aadhaar', 'license']
    document_number: str
    name: NameField

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
    request_id: RequestId
    status: Literal['PENDING']


class DigiLockerConsentSuccessResponseSchema(BaseModel):
    status: Literal['VERIFIED']
    name: str
    document_type: Literal['aadhaar', 'license']


class DigiLockerConsentFailureResponseSchema(BaseModel):
    status: Literal['FAILED']
    reason: str


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

