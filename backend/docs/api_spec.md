# Gig Insurance Backend API Specification

This document reflects the FastAPI routes currently mounted in `backend/main.py` and the current onboarding, DigiLocker, gig-income, premium, payment, claim, and support flows.

## Base URL

Local backend:

```text
http://127.0.0.1:8000
```

Real device on the same Wi-Fi:

```text
http://<your-laptop-ip>:8000
```

Examples:

- `http://192.168.0.6:8000`
- Android emulator: use `http://10.0.2.2:8000`

Health routes:

- `GET /`
- `GET /health`

## Runtime Notes

- CORS is enabled for all origins so the Flutter app can connect during development.
- SQLite is used by default in development.
- Email OTP and account-confirmation emails are sent through Mailtrap.
- SMS OTP is mocked and returned in the API response for demo use.
- DigiLocker is simulated. The app uses the generated `oauth_state` as the consent code in the mock flow.

## Error Shape

Handled errors use this shape:

```json
{
  "error": true,
  "message": "Description"
}
```

Typical examples:

```json
{
  "error": true,
  "message": "Invalid credentials"
}
```

```json
{
  "error": true,
  "message": "Account confirmation is still pending"
}
```

## API Summary

Route groups:

- Auth and onboarding
- DigiLocker
- Gig account and income
- Environment and risk
- Premium and payment
- Claims
- Support

## 1. Auth And Onboarding APIs

### `GET /auth/check-username?username=worker.one`

Checks live username availability.

Response:

```json
{
  "available": true,
  "suggestion": null,
  "message": "Username is available"
}
```

### `GET /auth/check-email?email=worker@example.com`

Checks live email availability.

### `GET /auth/suggest-usernames?username=worker`

Returns generated alternatives.

Response:

```json
{
  "suggestions": ["worker123", "worker781", "worker4421"]
}
```

### `POST /auth/signup`

Creates a new user in `pending_otp` state.

Request:

```json
{
  "email": "worker@example.com",
  "country_code": "+91",
  "phone_number": "9876543210",
  "username": "worker.one",
  "password": "Secure@123"
}
```

Validation rules:

- `email` must be unique
- `username` must be unique
- `phone` must be unique after `country_code + phone_number` normalization
- password must satisfy:
  - minimum 8 characters
  - at least 1 uppercase
  - at least 1 lowercase
  - at least 1 number
  - at least 1 special character

Response:

```json
{
  "user_id": 1,
  "email": "worker@example.com",
  "phone": "+919876543210",
  "username": "worker.one",
  "next_step": "otp_verification",
  "onboarding_status": "pending_otp"
}
```

### `POST /auth/send-otp`

Sends signup or reset OTP to both email and phone.

Request:

```json
{
  "user_id": 1,
  "purpose": "signup"
}
```

Notes:

- OTP expiry: 5 minutes
- retry limit: 5
- email OTP is sent by Mailtrap
- phone OTP is mocked and included in the response

Response:

```json
{
  "message": "OTP sent for signup",
  "purpose": "signup",
  "expires_in_seconds": 300,
  "retry_limit": 5,
  "deliveries": [
    {
      "channel": "email",
      "destination": "wo***@example.com",
      "mock_otp": null
    },
    {
      "channel": "phone",
      "destination": "+91***210",
      "mock_otp": "222222"
    }
  ]
}
```

### `POST /auth/verify-otp`

Verifies both signup OTPs and triggers the account-confirmation email.

Request:

```json
{
  "user_id": 1,
  "email_otp": "111111",
  "phone_otp": "222222"
}
```

Response:

```json
{
  "email_verified": true,
  "phone_verified": true,
  "confirmation_token": "<jwt>",
  "confirmation_link": "http://192.168.0.6:8000/auth/confirm?token=<jwt>",
  "next_step": "account_confirmation"
}
```

### `GET /auth/confirm?token=...`

Confirms the account after the user clicks the link from their email.

Response:

```json
{
  "account_confirmed": true,
  "next_step": "digilocker_verification",
  "message": "Account confirmed successfully"
}
```

### `GET /auth/onboarding-status?user_id=1`

Returns the current onboarding state for the user.

Response:

```json
{
  "user_id": 1,
  "is_email_verified": true,
  "is_phone_verified": true,
  "is_account_confirmed": true,
  "is_digilocker_verified": false,
  "next_step": "digilocker_verification"
}
```

### `POST /auth/login`

Logs in using email, username, or phone.

Request:

```json
{
  "identifier": "worker.one",
  "password": "Secure@123"
}
```

Login rules:

- blocked if account confirmation is incomplete
- blocked if DigiLocker is not verified
- first successful password login requires one-time second-step verification by either email or phone

Possible response for first login:

```json
{
  "requires_two_factor": true,
  "access_token": null,
  "token_type": null,
  "expires_in": null,
  "user": null,
  "two_factor_token": "<jwt>",
  "available_channels": ["email", "phone"],
  "message": "Choose email or phone for first-time login verification"
}
```

Possible response after the first-login challenge has already been completed:

```json
{
  "requires_two_factor": false,
  "access_token": "<jwt>",
  "token_type": "bearer",
  "expires_in": 43200,
  "user": {
    "id": 1,
    "email": "worker@example.com",
    "phone": "+919876543210",
    "username": "worker.one",
    "name": "worker.one",
    "is_email_verified": true,
    "is_phone_verified": true,
    "is_account_confirmed": true,
    "is_digilocker_verified": true,
    "has_completed_first_login_2fa": true,
    "created_at": "2026-04-03T09:30:00"
  },
  "two_factor_token": null,
  "available_channels": [],
  "message": "Login successful"
}
```

### `POST /auth/send-first-login-otp`

Sends the one-time first-login OTP to only one selected channel.

Request:

```json
{
  "challenge_token": "<jwt>",
  "channel": "email"
}
```

### `POST /auth/verify-first-login-otp`

Verifies the first-login OTP and returns the access token.

Request:

```json
{
  "challenge_token": "<jwt>",
  "channel": "email",
  "otp": "555555"
}
```

### `GET /auth/me`

Returns the authenticated user session.

Header:

```text
Authorization: Bearer <access_token>
```

### `POST /auth/forgot-password`

Starts reset flow by sending OTP to both email and phone.

Request:

```json
{
  "identifier": "worker.one"
}
```

### `POST /auth/verify-reset-otp`

Verifies both reset OTPs.

Request:

```json
{
  "user_id": 1,
  "email_otp": "333333",
  "phone_otp": "444444"
}
```

Response:

```json
{
  "reset_token": "<jwt>",
  "next_step": "reset_password",
  "message": "OTP verified. You can set a new password now."
}
```

### `POST /auth/reset-password`

Sets the new password.

Request:

```json
{
  "reset_token": "<jwt>",
  "new_password": "NewSecure@123"
}
```

### `POST /auth/verify-identity`

Legacy lightweight verification route used by the older flow. The main onboarding path now uses `/digilocker/*`.

## 2. DigiLocker APIs

DigiLocker is mandatory before normal login succeeds.

### `POST /digilocker/request`

Creates a mock DigiLocker authorization request.

Request:

```json
{
  "user_id": 1,
  "doc_type": "aadhaar"
}
```

Response:

```json
{
  "request_id": "6edb0a2e-88f2-4e1e-a9cc-6f6f7b0f38ab",
  "status": "PENDING",
  "provider_name": "DigiLocker",
  "redirect_url": "https://mock.digilocker.local/authorize?request_id=...",
  "oauth_state": "DL-123456"
}
```

### `POST /digilocker/verify`

Completes the mock DigiLocker verification.

Request:

```json
{
  "request_id": "6edb0a2e-88f2-4e1e-a9cc-6f6f7b0f38ab",
  "consent_code": "DL-123456"
}
```

Success response:

```json
{
  "status": "VERIFIED",
  "provider_name": "DigiLocker",
  "verified_name": "Perfect User",
  "doc_type": "aadhaar",
  "verified_at": "2026-04-03T11:12:13",
  "blockchain_txn_id": "MOCK-TXN-123"
}
```

Failure response:

```json
{
  "status": "FAILED",
  "reason": "Invalid DigiLocker consent code"
}
```

### `POST /digilocker/consent`

Alias of `/digilocker/verify` kept for compatibility.

### `GET /digilocker/status?user_id=1`

Returns the latest DigiLocker state.

Response:

```json
{
  "is_verified": true,
  "provider_name": "DigiLocker",
  "status": "VERIFIED",
  "verified_name": "Perfect User",
  "doc_type": "aadhaar",
  "verified_at": "2026-04-03T11:12:13",
  "verification_score": 0.98,
  "blockchain_txn_id": "MOCK-TXN-123"
}
```

## 3. Gig Account And Income APIs

### `POST /gig/connect`

Connects a gig platform and generates 30 days of simulated income history.

Request:

```json
{
  "user_id": 1,
  "platform": "Swiggy",
  "worker_id": "SWG123"
}
```

Notes:

- duplicate connection for the same `user_id + platform` is blocked
- `partner_id` is still accepted as a backward-compatible alias of `worker_id`
- generated rules:
  - base income `500-1200`
  - weekend boost `+100 to +300`
  - 20% chance of disruption
  - disruption reduces income by `30-70%`
  - hours between `6-10`

Response:

```json
{
  "message": "Swiggy account connected successfully",
  "income_generated": true,
  "status": "CONNECTED",
  "user_id": 1,
  "platform": "swiggy",
  "worker_id": "SWG123",
  "partner_id": "SWG123",
  "generated": 30
}
```

### `POST /gig/generate-data`

Utility route that generates synthetic gig data without creating a `GigAccount`.

Request:

```json
{
  "user_id": 1,
  "days": 30
}
```

### `GET /gig/income-history?user_id=1`

Returns stored gig-income history in reverse chronological order.

Response:

```json
[
  {
    "date": "2026-04-01",
    "income": 850.0,
    "hours": 8.0,
    "earnings": 850.0,
    "orders_completed": 16,
    "hours_worked": 8.0,
    "platform": "swiggy",
    "disruption_type": "none"
  }
]
```

### `GET /gig/baseline?user_id=1`

Primary baseline endpoint.

Logic:

- take the most recent 30 days
- sort by highest `earnings`
- average the top 10 days

Response:

```json
{
  "baseline_income": 920.0,
  "baseline_daily_income": 920.0
}
```

### `GET /gig/baseline-income?user_id=1`

Alias of `/gig/baseline` kept for older clients.

### `GET /gig/today-income?user_id=1`

Returns today’s gig income.

Response:

```json
{
  "date": "2026-04-03",
  "income": 780.0,
  "hours": 7.5,
  "earnings": 780.0,
  "orders_completed": 14,
  "hours_worked": 7.5,
  "disruption_type": "rain",
  "platform": "swiggy"
}
```

### `GET /gig/weekly-summary?user_id=1`

Returns the recent 7-day summary.

Response:

```json
{
  "total_income": 5200.0,
  "average_daily": 742.86,
  "avg_daily_earnings": 742.86,
  "total_orders": 95,
  "total_hours": 54.2,
  "total_loss_amount": 930.0,
  "avg_risk_score": 0.28,
  "best_day": {
    "date": "2026-04-01",
    "earnings": 980.0,
    "weather_condition": "clear",
    "traffic_level": "MEDIUM",
    "disruption_type": "none"
  },
  "worst_day": {
    "date": "2026-03-29",
    "earnings": 410.0,
    "weather_condition": "rain",
    "traffic_level": "HIGH",
    "disruption_type": "rain"
  }
}
```

### `GET /gig/debug-all`

Development helper that dumps all stored gig-income records.

## 4. Environment And Risk APIs

### `GET /environment?lat=13.0827&lon=80.2707`

Returns weather, AQI, traffic, and time-of-day context.

### `GET /risk?lat=13.0827&lon=80.2707&user_id=1`

Returns calculated risk plus optional gig context for the user.

## 5. Premium And Payment APIs

### `GET /premium?user_id=1`

Primary premium endpoint.

### `GET /premium/calculate?user_id=1`

Alias of the premium calculation endpoint.

Premium logic uses:

- gig baseline income
- city-resolved environmental context
- current risk score

### `POST /payment/link-bank`

Links a bank account for premium payments and claim payouts.

### `GET /payment/summary?user_id=1`

Returns insurance, bank, policy, and claim summary details for the user.

### `POST /payment/pay-premium`

Debits premium and creates a policy.

## 6. Bank API

### `POST /bank/link-account`

Compatibility route for linking a bank account.

## 7. Claim APIs

### `POST /claim/process`

Runs the claim engine and returns `APPROVED`, `REJECTED`, or `NEEDS_REVIEW`.

### `POST /claim/payout`

Processes payout for an approved claim.

## 8. Support API

### `POST /support/chat`

Rule-based support assistant that replies using the user’s latest claim and policy state.

## Current Main Flow

The current happy path in the mobile app is:

1. Signup
2. Send OTP to both email and phone
3. Verify both OTPs
4. Open the account-confirmation link from email
5. Complete DigiLocker verification
6. Connect gig account and generate 30 days of income history
7. First password login triggers one-time 2-step verification by either email or phone
8. App stores the session and can optionally enable biometric unlock
9. View premium, pay premium, and later submit a claim

## Notes

- `backend/routes/verification.py` exists but is not mounted in `backend/main.py`.
- The Flutter app currently uses the live backend routes above and expects the onboarding and gig APIs documented here.
