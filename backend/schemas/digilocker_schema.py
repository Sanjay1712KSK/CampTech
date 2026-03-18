from pydantic import BaseModel, Field


class DigiLockerRequestSchema(BaseModel):
    user_id: int = Field(..., gt=0)


class DigiLockerConsentSchema(BaseModel):
    request_id: str
    document_type: str = Field(..., regex='^(aadhaar|license)$')
    document_number: str
    name: str


class DigiLockerResponseSchema(BaseModel):
    status: str
    name: str | None = None
    document_type: str | None = None
    verified_data: dict | None = None
    reason: str | None = None
