from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserCreate(BaseModel):
    model_config = ConfigDict(extra='forbid')

    name: str = Field(..., min_length=2, max_length=255)
    email: EmailStr
    phone: str = Field(..., pattern='^[0-9]{10}$')
    password: str = Field(..., min_length=8)


class UserLogin(BaseModel):
    model_config = ConfigDict(extra='forbid')

    email: EmailStr
    password: str = Field(..., min_length=8)


class VerificationRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    user_id: int = Field(..., gt=0)
    document_type: str = Field(..., pattern='^(aadhaar|license)$')


class UserResponse(BaseModel):
    id: int
    name: str
    email: EmailStr
    phone: str
    is_verified: bool

    class Config:
        from_attributes = True
