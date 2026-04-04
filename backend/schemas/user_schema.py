from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator

from utils.security import PASSWORD_RULES_MESSAGE, validate_password_strength


PHONE_NUMBER_PATTERN = r'^\d{7,14}$'
COUNTRY_CODE_PATTERN = r'^\+\d{1,4}$'
USERNAME_PATTERN = r'^[a-zA-Z0-9_.]{3,24}$'
OTP_PATTERN = r'^\d{6}$'


class RegistrationRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    email: EmailStr
    country_code: str = Field(..., pattern=COUNTRY_CODE_PATTERN)
    phone_number: str = Field(..., pattern=PHONE_NUMBER_PATTERN)
    username: str = Field(..., pattern=USERNAME_PATTERN)
    password: str

    @field_validator('username')
    @classmethod
    def normalize_username(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator('password')
    @classmethod
    def validate_password(cls, value: str) -> str:
        if not validate_password_strength(value):
            raise ValueError(PASSWORD_RULES_MESSAGE)
        return value


class RegistrationResponse(BaseModel):
    user_id: int
    email: EmailStr
    phone: str
    username: str
    next_step: Literal['otp_verification']
    onboarding_status: str


class AvailabilityResponse(BaseModel):
    available: bool
    suggestion: str | None = None
    message: str


class UsernameSuggestionsResponse(BaseModel):
    suggestions: list[str]


class SendOtpRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    user_id: int = Field(..., gt=0)
    purpose: Literal['signup', 'reset'] = 'signup'


class OtpDeliveryPreview(BaseModel):
    channel: Literal['email', 'phone']
    destination: str
    status: Literal['sent', 'failed'] = 'sent'
    error_message: str | None = None
    mock_otp: str | None = None


class SendOtpResponse(BaseModel):
    message: str
    purpose: Literal['signup', 'reset', 'first_login']
    expires_in_seconds: int
    retry_limit: int
    deliveries: list[OtpDeliveryPreview]


class VerifyOtpRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    user_id: int = Field(..., gt=0)
    email_otp: str = Field(..., pattern=OTP_PATTERN)
    phone_otp: str = Field(..., pattern=OTP_PATTERN)


class VerifyOtpResponse(BaseModel):
    email_verified: bool
    phone_verified: bool
    email: EmailStr
    confirmation_token: str
    confirmation_link: str
    app_confirmation_link: str | None = None
    next_step: Literal['account_confirmation']


class ConfirmAccountResponse(BaseModel):
    user_id: int
    email: EmailStr
    account_confirmed: bool
    next_step: Literal['digilocker_verification']
    message: str


class OnboardingStatusResponse(BaseModel):
    user_id: int
    is_email_verified: bool
    is_phone_verified: bool
    is_account_confirmed: bool
    is_digilocker_verified: bool
    next_step: str


class LoginRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    identifier: str | None = None
    email: EmailStr | None = None
    password: str = Field(..., min_length=8)

    @model_validator(mode='after')
    def validate_identifier(self):
        identifier = self.identifier or self.email
        if not identifier:
            raise ValueError('identifier is required')
        self.identifier = str(identifier).strip()
        return self


class FirstLoginOtpRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    challenge_token: str = Field(..., min_length=16)
    channel: Literal['email', 'phone']


class FirstLoginOtpVerifyRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    challenge_token: str = Field(..., min_length=16)
    channel: Literal['email', 'phone']
    otp: str = Field(..., pattern=OTP_PATTERN)


class UserSessionResponse(BaseModel):
    id: int
    email: EmailStr
    phone: str
    username: str
    name: str
    is_email_verified: bool
    is_phone_verified: bool
    is_account_confirmed: bool
    is_digilocker_verified: bool
    has_completed_first_login_2fa: bool
    created_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class LoginResponse(BaseModel):
    requires_two_factor: bool = False
    access_token: str | None = None
    token_type: Literal['bearer'] | None = None
    expires_in: int | None = None
    user: UserSessionResponse | None = None
    two_factor_token: str | None = None
    available_channels: list[Literal['email', 'phone']] = []
    message: str | None = None


class ForgotPasswordRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    identifier: str = Field(..., min_length=3)


class ForgotPasswordResponse(BaseModel):
    user_id: int
    message: str
    expires_in_seconds: int
    deliveries: list[OtpDeliveryPreview]


class VerifyResetOtpRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    user_id: int = Field(..., gt=0)
    email_otp: str = Field(..., pattern=OTP_PATTERN)
    phone_otp: str = Field(..., pattern=OTP_PATTERN)


class VerifyResetOtpResponse(BaseModel):
    reset_token: str
    next_step: Literal['reset_password']
    message: str


class ResetPasswordRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    reset_token: str = Field(..., min_length=16)
    new_password: str

    @field_validator('new_password')
    @classmethod
    def validate_password(cls, value: str) -> str:
        if not validate_password_strength(value):
            raise ValueError(PASSWORD_RULES_MESSAGE)
        return value


class MessageResponse(BaseModel):
    message: str


class VerificationRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')

    user_id: int = Field(..., gt=0)
    document_type: Literal['aadhaar', 'passport']
