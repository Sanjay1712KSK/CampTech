from pydantic import BaseModel, Field


class DigiLockerRequest(BaseModel):
    user_id: int = Field(..., gt=0)


class DigiLockerRequestResponse(BaseModel):
    request_id: str
    status: str
    redirect_url: str


class ConsentRequest(BaseModel):
    request_id: str
    document_type: str = Field(..., pattern='^(aadhaar|license)$')
    document_number: str
    name: str


class VerificationResponse(BaseModel):
    status: str
    user_name: str | None = None
    document_type: str | None = None
    verified_data: dict | None = None
    reason: str | None = None
