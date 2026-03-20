# Gig Insurance Backend API Specification

This document describes the FastAPI backend that powers the gig worker insurance demo. It reflects the routes currently registered in `backend/main.py` and the validation enforced by the schemas in `backend/schemas`.

## Base URL

Local development:

```text
http://127.0.0.1:8000
```

Health routes:

- `GET /`
- `GET /health`

## Validation And Error Shape

The backend validates request bodies, query parameters, and most responses with Pydantic.

Common validation rules:

- `user_id` must be an integer greater than `0`
- `lat` must be between `-90` and `90`
- `lon` must be between `-180` and `180`
- `amount` must be greater than `0`
- request bodies reject undocumented extra fields where `extra='forbid'` is set

Handled errors use this shape:

```json
{
  "error": true,
  "message": "Description"
}
```

Examples:

```json
{
  "error": true,
  "message": "email: value is not a valid email address"
}
```

```json
{
  "error": true,
  "message": "Invalid credentials"
}
```

## API Summary

Current route groups:

- Auth
- DigiLocker
- Environment and risk
- Gig data
- Premium and payment
- Claims
- Support chat

## 1. Auth APIs

### `POST /auth/signup`

Creates a new user.

Request body:

```json
{
  "name": "Sanju",
  "email": "sanju@gmail.com",
  "phone": "9876543210",
  "password": "password123"
}
```

Notes:

- `name` minimum length: `2`
- `phone` must be exactly `10` digits
- duplicate email returns an error

Success response: `201 Created`

```json
{
  "id": 1,
  "name": "Sanju",
  "email": "sanju@gmail.com",
  "phone": "9876543210",
  "is_verified": false
}
```

### `POST /auth/login`

Authenticates an existing user.

Request body:

```json
{
  "email": "sanju@gmail.com",
  "password": "password123"
}
```

Success response: `200 OK`

```json
{
  "id": 1,
  "name": "Sanju",
  "email": "sanju@gmail.com",
  "phone": "9876543210",
  "is_verified": false
}
```

### `POST /auth/verify-identity`

Runs the lightweight identity verification flow used by the older auth path.

Request body:

```json
{
  "user_id": 1,
  "document_type": "aadhaar"
}
```

Typical success response:

```json
{
  "status": "verified",
  "document_type": "aadhaar"
}
```

## 2. DigiLocker APIs

### `POST /digilocker/request`

Creates a DigiLocker request record.

Request body:

```json
{
  "user_id": 1
}
```

Success response: `201 Created`

```json
{
  "request_id": "11111111-1111-1111-1111-111111111111",
  "status": "PENDING"
}
```

### `POST /digilocker/consent`

Submits consent details and verifies the document.

Request body:

```json
{
  "request_id": "11111111-1111-1111-1111-111111111111",
  "document_type": "aadhaar",
  "document_number": "123456789012",
  "name": "Sanju"
}
```

Validation notes:

- Aadhaar must contain exactly `12` digits
- License must contain `8` to `15` alphanumeric characters
- `name` must be at least 2 characters
- name matching is case-insensitive

Success response:

```json
{
  "status": "VERIFIED",
  "name": "Sanju",
  "document_type": "aadhaar"
}
```

Failure response:

```json
{
  "status": "FAILED",
  "reason": "Invalid document or mismatch"
}
```

### `GET /digilocker/status?user_id=1`

Returns the latest verification state for the user.

Success response:

```json
{
  "is_verified": true,
  "provider_name": "DigiLocker",
  "status": "VERIFIED",
  "verified_name": "Sanju",
  "document_type": "aadhaar",
  "document_number_masked": "********9012",
  "verified_at": "2026-03-20T12:34:56Z",
  "verification_score": 0.98,
  "blockchain_txn_id": "MOCK_TXN_1"
}
```

## 3. Environment API

### `GET /environment?lat=13.0827&lon=80.2707`

Returns live environmental context used by risk and claim logic.

Success response:

```json
{
  "weather": {
    "temperature": 31.2,
    "humidity": 72.4,
    "wind_speed": 6.8,
    "rainfall": 1.4
  },
  "aqi": {
    "aqi": 2,
    "pm2_5": 18.5,
    "pm10": 26.1
  },
  "traffic": {
    "traffic_score": 1.3,
    "traffic_level": "MEDIUM"
  },
  "context": {
    "hour": 18,
    "day_type": "weekday"
  }
}
```

## 4. Risk API

### `GET /risk?lat=13.0827&lon=80.2707&user_id=1`

Calculates delivery risk for the provided coordinates. If `user_id` is supplied, the response also includes today's gig context.

Success response:

```json
{
  "environment": {
    "weather": {
      "temperature": 31.2,
      "humidity": 72.4,
      "wind_speed": 6.8,
      "rainfall": 1.4
    },
    "aqi": {
      "aqi": 2,
      "pm2_5": 18.5,
      "pm10": 26.1
    },
    "traffic": {
      "traffic_score": 1.3,
      "traffic_level": "MEDIUM"
    },
    "context": {
      "hour": 18,
      "day_type": "weekday"
    }
  },
  "risk": {
    "risk_score": 0.72,
    "risk_level": "HIGH",
    "risk_factors": {
      "weather_risk": 0.8,
      "aqi_risk": 0.6,
      "traffic_risk": 0.8,
      "time_risk": 0.5
    },
    "recommendation": "Avoid delivery if possible"
  },
  "gig_context": {
    "earnings_today": 320.0,
    "orders_completed": 9
  }
}
```

Notes:

- `gig_context` is `null` when `user_id` is omitted or gig data is unavailable
- `risk_score` is normalized to `0.0` through `1.0`

## 5. Gig APIs

### `POST /gig/generate-data`

Generates mock gig history.

Request body:

```json
{
  "user_id": 1,
  "days": 30
}
```

Rules:

- `days` must be between `1` and `90`

### `POST /gig/connect`

Connects a partner account and generates fresh 30-day history.

Request body:

```json
{
  "user_id": 1,
  "platform": "swiggy",
  "partner_id": "SWG-PERFECT-001"
}
```

Rules:

- platform must be `swiggy` or `zomato`

Success response:

```json
{
  "status": "CONNECTED",
  "user_id": 1,
  "platform": "swiggy",
  "partner_id": "SWG-PERFECT-001",
  "generated": 30
}
```

### `GET /gig/income-history?user_id=1`

Returns stored gig records, newest first.

### `GET /gig/today-income?user_id=1`

Returns the newest stored record for the user, or a generated fallback payload if none exists yet.

### `GET /gig/baseline-income?user_id=1`

Example response:

```json
{
  "baseline_daily_income": 850.0
}
```

### `GET /gig/weekly-summary?user_id=1`

Returns aggregate performance for the latest week.

Example response:

```json
{
  "avg_daily_earnings": 512.4,
  "total_orders": 68,
  "total_hours": 42.5,
  "total_loss_amount": 940.0,
  "avg_risk_score": 0.49,
  "best_day": {
    "date": "2026-03-16",
    "earnings": 780.0,
    "weather_condition": "clear",
    "traffic_level": "LOW",
    "disruption_type": "none"
  },
  "worst_day": {
    "date": "2026-03-19",
    "earnings": 260.0,
    "weather_condition": "rain",
    "traffic_level": "HIGH",
    "disruption_type": "rain"
  }
}
```

### `GET /gig/debug-all`

Debug-only helper that returns all stored gig rows.

## 6. Premium API

### `GET /premium?user_id=1`

### `GET /premium/calculate?user_id=1`

Both routes return the same premium calculation response:

```json
{
  "baseline": 850.0,
  "weekly_income": 5950.0,
  "risk_score": 0.34,
  "weekly_premium": 200.0
}
```

## 7. Payment And Bank APIs

### `GET /payment/summary?user_id=1`

Returns the bank, policy, and claim summary used by the Home, AI Engine, and Profile screens.

Success response:

```json
{
  "user_id": 1,
  "bank_linked": true,
  "account_number_masked": "****9012",
  "ifsc": "HDFC0001234",
  "balance": 9800.0,
  "total_paid": 200.0,
  "total_claimed": 640.0,
  "policy_status": "EXPIRED",
  "policy_start": "2026-03-13",
  "policy_end": "2026-03-19",
  "claim_ready": true,
  "claim_message": "Ready to claim previous completed week",
  "last_payout": 640.0,
  "latest_claim_status": "APPROVED",
  "recent_remarks": [
    "Claim payout credited for claim_12",
    "Weekly premium paid for policy #9"
  ]
}
```

### `POST /payment/link-bank`

Links or updates the user's bank account.

Request body:

```json
{
  "user_id": 1,
  "account_number": "123456789012",
  "ifsc": "HDFC0001234"
}
```

Success response:

```json
{
  "status": "LINKED",
  "user_id": 1,
  "balance": 10000.0
}
```

### `POST /payment/pay-premium`

Debits the linked bank account and creates a 7-day policy.

Request body:

```json
{
  "user_id": 1,
  "amount": 200.0
}
```

Success response:

```json
{
  "status": "SUCCESS",
  "user_id": 1,
  "amount": 200.0,
  "balance": 9800.0,
  "transaction_id": "8e95b0e8-f8fd-4f4b-8db7-79b1f9f8f24a",
  "blockchain_txn_id": "MOCK-TXN"
}
```

Related legacy route:

- `POST /bank/link-account`

New integrations should prefer `POST /payment/link-bank`.

## 8. Claim APIs

### `POST /claim/process`

Processes a claim for the user's latest completed policy week.

Request body:

```json
{
  "user_id": 1,
  "lat": 13.0827,
  "lon": 80.2707
}
```

Important behavior:

- the user must have at least 7 days of gig history
- the user must work at least 80% of the time in one city
- a completed paid policy week must exist
- approved claims are automatically credited to the linked bank account
- rejected and review outcomes still create claim records

Approved response:

```json
{
  "status": "APPROVED",
  "weekly_loss": 800.0,
  "loss": 800.0,
  "payout": 640.0,
  "fraud_score": 0.18,
  "reasons": null
}
```

Rejected response:

```json
{
  "status": "REJECTED",
  "weekly_loss": null,
  "loss": null,
  "payout": null,
  "fraud_score": 1.0,
  "reasons": [
    "No completed policy week is available to claim yet"
  ]
}
```

Review response:

```json
{
  "status": "NEEDS_REVIEW",
  "weekly_loss": null,
  "loss": null,
  "payout": null,
  "fraud_score": 0.51,
  "reasons": [
    "Claim validation failed"
  ]
}
```

### `POST /claim/payout`

Manual payout helper for review or admin-assisted flows.

Request body:

```json
{
  "user_id": 1,
  "amount": 500.0,
  "claim_id": "claim_17"
}
```

Success response:

```json
{
  "status": "SUCCESS",
  "user_id": 1,
  "amount": 500.0,
  "balance": 10500.0,
  "transaction_id": "claim_17",
  "blockchain_txn_id": "MOCK-TXN"
}
```

## 9. Support API

### `POST /support/chat`

Returns a support response based on the latest claim status.

Request body:

```json
{
  "user_id": 1,
  "query": "Why was my claim rejected?"
}
```

Success response:

```json
{
  "response": "Your latest claim was rejected because no eligible weekly loss detected. Please review your disruption evidence, keep city-consistent work history, and wait until the policy period ends before claiming again."
}
```

Behavior summary:

- no claim yet: explains policy and claim prerequisites
- rejected claim: explains likely reason and next steps
- approved claim: confirms payout
- `NEEDS_REVIEW`: asks the user to keep location and proof ready for manual review

## cURL Examples

### Health

```bash
curl "http://127.0.0.1:8000/health"
```

### Connect Gig Account

```bash
curl -X POST "http://127.0.0.1:8000/gig/connect" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "platform": "swiggy",
    "partner_id": "SWG-PERFECT-001"
  }'
```

### Payment Summary

```bash
curl "http://127.0.0.1:8000/payment/summary?user_id=1"
```

### Pay Premium

```bash
curl -X POST "http://127.0.0.1:8000/payment/pay-premium" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "amount": 200.0
  }'
```

### Process Claim

```bash
curl -X POST "http://127.0.0.1:8000/claim/process" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "lat": 13.0827,
    "lon": 80.2707
  }'
```

### Support Chat

```bash
curl -X POST "http://127.0.0.1:8000/support/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "query": "What should I do next?"
  }'
```

## Developer Notes

- `backend/main.py` currently mounts auth, bank, claim, digilocker, environment, gig, payment, premium, risk, and support routers
- `POST /payment/pay-premium` creates a 7-day policy window
- `POST /claim/process` only allows claiming against a completed paid week, not the currently active week
- seeded demo users from `backend/scripts/seed_demo_data.py` already have expired paid policies, linked banks, and DigiLocker-ready profiles for walkthroughs
