# Gig Insurance Demo Walkthrough

This walkthrough is updated for the current app flow:

- signup with dual OTP
- account confirmation by email link
- mandatory DigiLocker verification
- gig account connection
- first-login one-time second-step verification
- premium, claim, payout, and support flows

## Before You Start

1. Start the backend:

```bash
cd backend
python main.py
```

2. Seed demo users if you want the prebuilt claim scenarios:

```bash
python scripts/seed_demo_data.py
```

3. Point the Flutter app to the backend base URL:

```text
Real device: http://<your-laptop-ip>:8000
Android emulator: http://10.0.2.2:8000
```

4. Verify the backend is up:

```text
GET /health -> {"status":"ok"}
```

## Two Demo Paths

Use one of these depending on what you want to show.

### Path A: Fresh User Onboarding

Best when you want to show:

- realistic fintech onboarding
- email OTP + phone OTP
- email confirmation link
- mandatory DigiLocker
- gig account connection
- first-login verification and biometric prompt

### Path B: Seeded Claim Scenarios

Best when you want to show:

- premium and claim decisions quickly
- approved / rejected / review paths
- support explanations after a claim result

## Path A: Fresh User Onboarding Walkthrough

### 1. Sign Up

In the app, enter:

```text
Email: your demo email
Country code: +91
Phone: your phone number
Username: any available username
Password: Secure@123
```

Expected result:

- account is created in `pending_otp`
- username and email checks work live

### 2. OTP Verification

Tap continue and wait for OTP delivery.

What happens:

- email OTP is sent through Mailtrap to the user email
- phone OTP is mocked and shown in the app for demo use

Expected result:

- enter both OTPs
- app moves to account confirmation

### 3. Account Confirmation

What happens:

- backend sends a confirmation email to the user email address
- the email contains a link to `GET /auth/confirm?token=...`

Demo options:

- Preferred: open the email on the phone and tap the confirmation link
- Fallback in app: use the demo confirmation button if needed

Expected result:

- account becomes confirmed
- next required step is DigiLocker

### 4. Mandatory DigiLocker Verification

Choose one:

- `aadhaar`
- `passport`

What happens:

- app calls `/digilocker/request`
- app uses the returned `oauth_state` as the mock consent code
- app calls `/digilocker/verify`

Expected result:

- user is marked DigiLocker verified
- app continues directly to gig account connection

Important note:

- this step is mandatory
- normal login is blocked until DigiLocker is verified

### 5. Connect Gig Account

Use:

```text
Platform: Swiggy or Zomato
Worker ID: SWG123 or ZMT123
```

What happens:

- backend stores the gig account
- 30 days of income data are generated automatically

Generated rules:

- base income `500-1200`
- weekend boost `+100 to +300`
- 20% disruption chance
- disruption reduces income by `30-70%`
- hours between `6-10`

Expected result:

- account connected successfully
- income history becomes available immediately

### 6. First Login Verification

On the first password login after onboarding:

- backend returns a first-login challenge
- user chooses only one channel:
  - email
  - phone
- OTP is sent only to that selected channel

Expected result:

- after OTP verification, the access token is returned
- later logins skip this first-login challenge

### 7. Session And Biometric

After the first successful authenticated entry:

- app stores the session
- app can prompt once to enable biometric unlock

Expected result:

- reopening the app keeps the user logged in
- if biometric is enabled, the app can require biometric unlock on reopen

## Path B: Seeded Claim Scenarios

All seeded users share the same password:

```text
securePass123
```

The seeded demo users already include:

- DigiLocker-verifiable identity data
- bank accounts
- scenario-specific gig records
- claim-ready policy state for walkthroughs

If you buy a new premium during the demo:

- the newest policy becomes active
- that active policy is not immediately claimable

## Common Demo Inputs

### Gig Account Connection

Use one of these:

- `Swiggy`
- `Zomato`

Sample worker IDs:

- `SWG-PERFECT-001`
- `ZMT-FRAUD-002`
- `SWG-INSUFF-003`
- `ZMT-NORMAL-004`
- `SWG-EDGE-005`

### Bank Linking

```text
Account Number: 123456789012
IFSC: HDFC0001234
```

### Location

Use Chennai for the cleanest demo:

```text
Latitude: 13.0827
Longitude: 80.2707
City: Chennai
```

## Seeded User Scenarios

### 1. Perfect User

Login:

```text
Email: perfect_user@test.com
Password: securePass123
```

Best for:

- happy-path claim approval
- payout demo
- support explanation after approval

Recommended flow:

1. Log in as `perfect_user@test.com`
2. Open `Home`, `Risk`, and `AI Engine`
3. Connect gig account if you want to refresh income:

```text
Platform: Swiggy
Worker ID: SWG-PERFECT-001
```

4. Confirm policy state is claim-ready
5. Trigger claim
6. Expected result: `APPROVED`
7. Open `Profile` or payment summary and confirm payout details
8. Open support and ask:

```text
Was my payout credited?
```

### 2. Fraud User

Login:

```text
Email: fraud_user@test.com
Password: securePass123
```

Best for:

- fraud rejection
- support explanation for a denied claim

Recommended flow:

1. Log in as `fraud_user@test.com`
2. Optionally refresh gig history:

```text
Platform: Zomato
Worker ID: ZMT-FRAUD-002
```

3. Open `Risk`
4. Trigger claim
5. Expected result: `REJECTED`
6. Open support and ask:

```text
Why was my claim rejected?
```

### 3. Insufficient Data User

Login:

```text
Email: insufficient_user@test.com
Password: securePass123
```

Best for:

- early-stage user
- insufficient eligibility data

Recommended flow:

1. Log in as `insufficient_user@test.com`
2. Optionally connect:

```text
Platform: Swiggy
Worker ID: SWG-INSUFF-003
```

3. Open `Home`, `Risk`, or `AI Engine`
4. Trigger claim
5. Expected result:
   - blocked or rejected
   - reason mentions insufficient data or eligibility failure

### 4. Normal Week User

Login:

```text
Email: normal_week_user@test.com
Password: securePass123
```

Best for:

- stable earnings
- no valid payout event

Recommended flow:

1. Log in as `normal_week_user@test.com`
2. Optionally connect:

```text
Platform: Zomato
Worker ID: ZMT-NORMAL-004
```

3. Open `AI Engine` or `Claim`
4. Expected result: `REJECTED`
5. Typical reason:

```text
No eligible weekly loss detected
```

### 5. Escalation User

Login:

```text
Email: escalation_user@test.com
Password: securePass123
```

Best for:

- borderline signals
- review / escalation branch

Recommended flow:

1. Log in as `escalation_user@test.com`
2. Optionally connect:

```text
Platform: Swiggy
Worker ID: SWG-EDGE-005
```

3. Open `Risk` or `AI Engine`
4. Trigger claim
5. Expected result:
   - `NEEDS_REVIEW` or another borderline outcome
6. Open support and ask:

```text
What should I do next?
```

## Suggested Judge Sequence

Use this order for a clean live demo.

### Flow 1: Real Onboarding

1. Signup
2. OTP verification
3. Show confirmation email
4. Complete DigiLocker
5. Connect gig account
6. Show income history screen
7. Log in and show first-login OTP challenge
8. Show biometric prompt / persistent session

### Flow 2: Approved Claim

Use `perfect_user@test.com`

1. Log in
2. Show risk and premium
3. Trigger claim
4. Show approved payout
5. Show updated summary

### Flow 3: Rejected Claim

Use `fraud_user@test.com`

1. Log in
2. Trigger claim
3. Show rejection
4. Ask support why it failed

## Notes

- The app’s current onboarding flow is stricter than the old docs:
  - email confirmation is expected
  - DigiLocker is mandatory
  - first login uses a one-time second-step verification
- Connecting a gig account generates fresh mock income history.
- The cleanest risk and claim demo location remains `Chennai`.
- If you reseed demo data, the same seeded users are refreshed.
