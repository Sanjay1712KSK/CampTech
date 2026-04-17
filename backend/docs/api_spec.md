# Gig Insurance Backend API Specification

This document reflects the FastAPI routes currently mounted in [backend/main.py](s:\flutter\guidewire_gig_ins\backend\main.py). It covers the live backend surface used by the Flutter worker app, the insurer admin dashboard, the adaptive prediction layer, and the live demo pipeline.

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
- Android emulator: `http://10.0.2.2:8000`

Health routes:

- `GET /`
- `GET /health`

## Runtime Notes

- CORS is enabled for development connectivity.
- SQLite is the default local database.
- Email OTP and confirmation mail use Brevo SMTP.
- SMS OTP is mocked for demo use and can be returned in auth responses.
- DigiLocker is simulated.
- Claims support both manual processing and zero-touch parametric auto-processing.
- Fraud checks, payouts, and predictions are data-driven and feed the worker and admin dashboards.
- The worker Home dashboard includes a live demo control panel backed by environment override APIs and a consolidated demo pipeline endpoint.

## Error Shape

Handled errors generally follow:

```json
{
  "error": true,
  "message": "Description"
}
```

FastAPI validation failures use the default `detail` list shape.

## Route Groups

- Auth and onboarding
- DigiLocker
- Gig account and income
- Environment, risk, and premium
- Bank, payment, and policy
- Claims and payout
- Worker dashboard APIs
- Admin dashboard APIs
- Simulation and support

## 1. Auth And Onboarding

### `GET /auth/check-username?username=worker.one`

Checks username availability.

Response:

```json
{
  "available": true,
  "suggestion": null,
  "message": "Username is available"
}
```

### `GET /auth/check-email?email=worker@example.com`

Checks email availability.

### `GET /auth/suggest-usernames?username=worker`

Returns alternative usernames.

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

Sends OTP to email and phone for signup or reset.

Request:

```json
{
  "user_id": 1,
  "purpose": "signup"
}
```

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

Verifies both OTPs and prepares account confirmation.

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

Confirms account ownership.

### `GET /auth/onboarding-status?user_id=1`

Returns current onboarding state.

### `POST /auth/login`

Logs in using email, username, or phone. If first-login second-step verification is still pending, returns a challenge token instead of an access token.

### `POST /auth/send-first-login-otp`

Sends a one-time first-login OTP to a selected channel.

Request:

```json
{
  "challenge_token": "<jwt>",
  "channel": "email"
}
```

### `POST /auth/verify-first-login-otp`

Verifies the first-login OTP and returns the normal access token payload.

### `GET /auth/me`

Returns the authenticated user session.

Header:

```text
Authorization: Bearer <access_token>
```

### `POST /auth/forgot-password`

Starts password reset by sending OTP to email and phone.

### `POST /auth/verify-reset-otp`

Verifies reset OTPs and returns a reset token.

### `POST /auth/reset-password`

Sets a new password.

### `POST /auth/verify-identity`

Legacy lightweight identity verification endpoint kept for compatibility.

## 2. DigiLocker

### `POST /digilocker/request`

Creates a mock DigiLocker authorization request.

Request:

```json
{
  "user_id": 1,
  "doc_type": "aadhaar"
}
```

### `POST /digilocker/verify`

Completes the mock DigiLocker flow.

Request:

```json
{
  "request_id": "6edb0a2e-88f2-4e1e-a9cc-6f6f7b0f38ab",
  "consent_code": "DL-123456"
}
```

### `POST /digilocker/consent`

Compatibility alias of `/digilocker/verify`.

### `GET /digilocker/status?user_id=1`

Returns the latest DigiLocker status.

## 3. Gig Account And Income

### `POST /gig/connect`

Connects a gig platform and generates simulated income history.

Request:

```json
{
  "user_id": 1,
  "platform": "Swiggy",
  "worker_id": "SWG123"
}
```

### `POST /gig/generate-data`

Generates synthetic gig data without creating a connected gig account.

### `GET /gig/income-history?user_id=1`

Returns gig-income history in reverse chronological order.

### `GET /gig/status?user_id=1`

Returns whether the user has a connected gig account.

### `GET /gig/debug-all`

Development helper that dumps all stored gig-income rows.

### `GET /gig/baseline?user_id=1`

Primary baseline endpoint.

### `GET /gig/baseline-income?user_id=1`

Alias of `/gig/baseline`.

### `GET /gig/today-income?user_id=1`

Returns the latest stored daily gig snapshot.

### `GET /gig/weekly-summary?user_id=1`

Returns recent 7-day income and disruption summary.

## 4. Environment, Risk, Premium, And Demo Controls

### `GET /environment?lat=13.0827&lon=80.2707`

Returns environment context, including weather, AQI, traffic, and recent comparison data.

### `GET /environment/current?lat=13.0827&lon=80.2707`

Alias of `/environment`. Intended for UI flows that explicitly request the current environment snapshot.

### `POST /environment/override`

Controls the live demo environment override mode.

Request:

```json
{
  "override_mode": true,
  "rain": "HIGH",
  "traffic": "HIGH",
  "aqi": "MEDIUM",
  "scenario": "rain"
}
```

Supported scenarios:

- `rain`
- `fraud`
- `reset`

Behavior:

- If `override_mode=true`, the backend overlays the selected disruption levels on top of the normal environment response.
- If `override_mode=false` or `scenario=reset`, the backend returns to live/simulated environment behavior.

Response:

```json
{
  "override_mode": true,
  "scenario": "rain",
  "rain": "HIGH",
  "traffic": "HIGH",
  "aqi": "MEDIUM"
}
```

### `GET /risk?lat=13.0827&lon=80.2707&user_id=1`

Returns risk engine output, including:

- `risk_score`
- `risk_level`
- `expected_income_loss`
- `delivery_efficiency`
- `active_triggers`
- `reasons`
- `factors`
- predictive and hyperlocal context

### `GET /premium?user_id=1&lat=13.0827&lon=80.2707`

Primary premium calculation endpoint.

### `GET /premium/calculate?user_id=1&lat=13.0827&lon=80.2707`

Alias of `/premium`.

Premium response includes:

```json
{
  "baseline": 920.0,
  "weekly_income": 6440.0,
  "weekly_premium": 126.35,
  "coverage": 5152.0,
  "risk_score": 0.28,
  "risk": {},
  "explanation": "Premium generated from live risk conditions"
}
```

### `GET /demo/full-pipeline?user_id=1&lat=13.0827&lon=80.2707`

Returns the complete live demo pipeline payload used by the Home dashboard demo panel.

Response sections:

- `scenario`
- `override`
- `environment`
- `risk`
- `premium`
- `claim`
- `fraud`
- `payout`

Example:

```json
{
  "scenario": "rain",
  "override": {
    "override_mode": true,
    "scenario": "rain",
    "rain": "HIGH",
    "traffic": "HIGH",
    "aqi": "MEDIUM"
  },
  "environment": {},
  "risk": {},
  "premium": {},
  "claim": {
    "claim_triggered": true,
    "status": "APPROVED"
  },
  "fraud": {
    "fraud_score": 0.18,
    "decision": "APPROVED"
  },
  "payout": {
    "status": "SUCCESS",
    "amount_paid": 320.0,
    "transaction_id": "txn_demo_123"
  }
}
```

## 5. Bank, Payment, And Policy

### `POST /bank/link-account`

Compatibility route for linking a bank account.

### `POST /payment/link-bank`

Primary route for linking a bank account.

Request:

```json
{
  "user_id": 1,
  "account_number": "123456789012",
  "ifsc": "HDFC0001234"
}
```

### `GET /payment/summary?user_id=1`

Returns worker insurance and payout summary.

Important fields:

- `bank_linked`
- `total_paid`
- `total_claimed`
- `policy_status`
- `claim_ready`
- `last_payout`
- `payout_status`
- `payout_transaction_id`
- `payout_time`
- `latest_claim_status`

### `GET /payment/transactions?user_id=1&limit=10`

Returns bank transaction history.

### `POST /payment/pay-premium`

Debits premium, creates a policy, logs a bank transaction, and writes blockchain records.

Request:

```json
{
  "user_id": 1,
  "amount": 126.35
}
```

Response:

```json
{
  "status": "SUCCESS",
  "user_id": 1,
  "amount": 126.35,
  "balance": 4873.65,
  "transaction_id": "txn_123",
  "blockchain_txn_id": "mock_chain_123"
}
```

## 6. Claims And Payout

### `POST /claim/process`

Runs the manual claim pipeline:

Environment -> Risk -> Premium -> Fraud Intelligence -> Claim Decision -> Payout -> Blockchain

Request:

```json
{
  "user_id": 1,
  "lat": 13.0827,
  "lon": 80.2707,
  "device_id": "android_device_01",
  "device_metadata": {
    "model": "Samsung A34",
    "os": "Android 14",
    "app_version": "1.0.0"
  },
  "location_logs": [
    {
      "lat": 13.08,
      "lon": 80.27,
      "timestamp": "2026-04-16T10:30:00"
    }
  ],
  "claim_reason": "rain"
}
```

Response fields include:

- `claim_status`
- `status`
- `reason`
- `expected_income`
- `actual_income`
- `loss`
- `payout`
- `predicted_loss`
- `fraud_score`
- `confidence`
- `fraud`
- `transaction`
- `blockchain`
- `environment`
- `risk`
- `premium`
- `policy`
- `gig`
- `location_status`
- `claim_id`
- `fraud_log_id`

### `POST /claim/auto-process`

Runs the zero-touch parametric claim engine. No manual claim proof is required.

Request:

```json
{
  "user_id": 1,
  "lat": 13.0827,
  "lon": 80.2707
}
```

Response:

```json
{
  "claim_triggered": true,
  "status": "APPROVED",
  "loss": 320.0,
  "confidence": "HIGH",
  "fraud": {},
  "payout": {
    "status": "SUCCESS",
    "amount_paid": 320.0,
    "transaction_id": "txn_demo_123",
    "processing_time": "1.2 seconds",
    "message": "Payout successfully credited"
  },
  "explanation": "Claim triggered due to rain and a 40% drop in earnings compared to the normal baseline during the current monitoring window.",
  "trigger": "rain",
  "timestamp": "2026-04-16T12:00:00",
  "claim_id": "claim_10",
  "trigger_details": {},
  "loss_percentage": 0.4,
  "location_status": {},
  "blockchain": {
    "claim": {},
    "payout": {}
  }
}
```

### `POST /claim/payout`

Manual payout route for approved claims or demo payout simulation.

Request:

```json
{
  "user_id": 1,
  "amount": 320.0,
  "claim_id": "claim_10"
}
```

## 7. Worker Dashboard APIs

These routes are UI-ready and are intended to drive the worker dashboard directly.

### `GET /dashboard/worker?user_id=1&lat=13.0827&lon=80.2707`

Returns the aggregated worker dashboard payload.

Response sections:

- `user`
- `environment`
- `risk`
- `premium`
- `policy`
- `payout`
- `prediction`
- `status`

Example shape:

```json
{
  "user": {},
  "environment": {},
  "risk": {},
  "premium": {},
  "policy": {},
  "payout": {
    "payout_status": "SUCCESS",
    "amount": 320.0,
    "transaction_id": "txn_demo_123",
    "time": "2026-04-16T12:00:00"
  },
  "prediction": {
    "next_6hr_risk": "HIGH",
    "risk_trend": "increasing",
    "predicted_risk_score": 0.74,
    "message": "If current conditions continue, your risk may increase over the next few hours.",
    "insights": [
      "Heavy rainfall trend may increase claims in the next cycle"
    ]
  },
  "status": {
    "coverage_active": true,
    "auto_payout_enabled": true,
    "device": {},
    "location": {}
  }
}
```

### `GET /risk/details?user_id=1&lat=13.0827&lon=80.2707`

Risk-detail response designed for UI cards.

Response fields:

- `risk_score`
- `factors`
- `triggers`
- `risk_level`
- `explanation`
- `last_updated`

### `GET /premium/details?user_id=1&lat=13.0827&lon=80.2707`

Premium-detail response designed for UI cards.

Response fields:

- `weekly_income`
- `risk_score`
- `premium`
- `coverage`
- `breakdown`
- `eligible`
- `reason`
- `explanation`
- `last_updated`

### `GET /transactions/history?user_id=1&limit=10`

UI-ready transaction history for worker surfaces.

Each item includes:

- `type`
- `amount`
- `transaction_id`
- `status`
- `created_at`
- `remark`

### `GET /user/device-status?user_id=1`

Returns device-state information used by fraud and trust surfaces.

### `GET /user/location-status?user_id=1`

Returns current location-state information. If `lat` and `lon` are included, the backend updates the user’s location state and then returns it.

## 8. Admin Dashboard APIs

These routes require:

```text
Authorization: Bearer admin_token
```

For demo use, login is static.

### `POST /admin/login`

Request:

```json
{
  "email": "admin@gigshield.com",
  "password": "admin123"
}
```

Response:

```json
{
  "token": "admin_token",
  "role": "insurer"
}
```

### `GET /admin/overview`

Returns platform summary:

```json
{
  "total_users": 20,
  "active_policies": 8,
  "total_claims": 14,
  "total_payouts": 12450.0,
  "total_premiums": 18200.0,
  "loss_ratio": 0.6841
}
```

### `GET /admin/fraud-stats`

Returns fraud analytics:

- `fraud_rate`
- `flagged_claims`
- `rejected_claims`
- `top_fraud_types`
- `hotspots`

Example:

```json
{
  "fraud_rate": 0.2143,
  "flagged_claims": 2,
  "rejected_claims": 1,
  "top_fraud_types": [
    {
      "type": "gps_spoof",
      "count": 3
    }
  ],
  "hotspots": [
    {
      "city": "Chennai",
      "count": 2
    }
  ]
}
```

### `GET /admin/claims-stats`

Returns:

- `approved`
- `rejected`
- `flagged`
- `avg_payout`
- `avg_loss`

### `GET /admin/risk-stats`

Returns:

- `high_risk_users`
- `avg_risk_score`
- `top_triggers`

### `GET /admin/financials`

Returns:

- `total_premiums`
- `total_payouts`
- `profit`

### `GET /admin/payouts`

Returns payout performance:

- `total_payouts`
- `avg_payout`
- `payout_success_rate`

### `GET /admin/predictions`

Returns the lightweight ML and prediction-engine output.

Response fields:

- `next_6hr_risk`
- `predicted_claims`
- `next_week_claims`
- `expected_payout`
- `risk_trend`
- `insights`
- `insight`

Example:

```json
{
  "next_6hr_risk": "HIGH",
  "predicted_claims": 12,
  "next_week_claims": 12,
  "expected_payout": 4860.0,
  "risk_trend": "increasing",
  "insights": [
    "Heavy rainfall trend may increase claims in the next cycle",
    "Rising risk levels indicate higher payouts may be needed soon"
  ],
  "insight": "Heavy rainfall trend may increase claims in the next cycle"
}
```

## 9. Simulation And Support

### `POST /simulate/input`

Seeds or refreshes simulation inputs used by personas and environment-driven demos.

Typical request:

```json
{
  "enable_simulation": true,
  "regenerate_income": true,
  "days": 30
}
```

### `POST /support/chat`

Rule-based support assistant that responds using the user’s latest claim and policy state.

Request:

```json
{
  "user_id": 1,
  "query": "Why was my claim rejected?"
}
```

## Current Demo Flow

The main worker demo flow is:

1. Signup
2. Send OTP to email and phone
3. Verify OTPs
4. Confirm account from email
5. Complete DigiLocker verification
6. Connect gig account and generate income history
7. Login and complete first-login OTP challenge if required
8. View worker dashboard and premium details
9. Pay premium
10. Trigger either manual claim processing or zero-touch auto-claim processing
11. Inspect payout, fraud, transaction history, and admin analytics

## Live Demo Pipeline Flow

The main stage demo flow is now:

1. Log in as a worker persona
2. Open the `Home` tab
3. Use the `Demo Control Panel`
4. Tap `Trigger Rain` for the approved path or `Trigger Fraud` for the suspicious path
5. Watch the `Live Demo Pipeline` animate:
   - Environment
   - Risk
   - Claim
   - Fraud
   - Payout
6. Open `Insurance` and `Claims` to reinforce the same story
7. Open the admin dashboard to show fraud, payouts, and predictions updating from the same backend

### Demo Scenario A: Protected Worker

- Use `Trigger Rain`
- Expected story:
  - severe disruption
  - higher risk
  - auto-triggered claim
  - fraud approved
  - payout credited

### Demo Scenario B: Fraud-Aware Rejection

- Use `Trigger Fraud`
- Expected story:
  - low disruption context
  - suspicious claim path
  - fraud mismatch signals
  - payout blocked or skipped

### Reset

- Use `Reset`
- Backend returns to live or seeded environment behavior
- The worker dashboard stops showing an active forced demo scenario

## Notes

- [backend/routes/verification.py](s:\flutter\guidewire_gig_ins\backend\routes\verification.py) exists but is not mounted in [backend/main.py](s:\flutter\guidewire_gig_ins\backend\main.py).
- The worker dashboard consumes the UI-ready APIs documented above rather than reconstructing business logic on the client.
- The admin dashboard uses the `/admin/*` analytics routes and the lightweight prediction engine for decision-oriented insights.
