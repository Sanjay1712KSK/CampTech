# Gig Insurance Demo Walkthrough

This walkthrough is updated for the current app flow and the new live demo pipeline:

- signup with dual OTP
- account confirmation by email link
- mandatory DigiLocker verification
- gig account connection
- first-login one-time second-step verification
- premium, claim, payout, and support flows
- live demo control panel on the worker dashboard
- animated pipeline view for `Environment -> Risk -> Claim -> Fraud -> Payout`

## Before You Start

1. Start the backend:

```bash
cd backend
python main.py
```

2. Seed simulation inputs and demo actors if needed:

```bash
python scripts/seed_demo_data.py
```

and optionally:

```http
POST /simulate/input
Content-Type: application/json

{
  "enable_simulation": true,
  "regenerate_income": true,
  "days": 30
}
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

5. Confirm these before the presentation starts:

- worker login works
- admin login works
- Home dashboard opens without error
- Insurance page opens without error
- phone and laptop are on the same Wi-Fi

## Demo Paths

Choose one of these based on what you want to emphasize.

### Path A: Fresh User Onboarding

Best when you want to show:

- realistic fintech onboarding
- email OTP + phone OTP
- email confirmation link
- mandatory DigiLocker
- gig account connection
- first-login verification and biometric prompt

### Path B: Seeded Persona Story

Best when you want to show:

- prebuilt worker behavior
- different risk and fraud outcomes
- good actor vs bad actor comparison

### Path C: Live Pipeline Demo

Best when you want to show:

- a real-time parametric insurance story
- disruption control from the UI
- automatic claim triggering
- fraud-aware approval or rejection
- instant payout visibility
- insurer analytics reacting to the same backend flow

## Path A: Fresh User Onboarding Walkthrough

### 1. Sign Up

Enter:

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

- email OTP is sent through Brevo SMTP
- phone OTP is mocked and shown in the app

Expected result:

- enter both OTPs
- app moves to account confirmation

### 3. Account Confirmation

What happens:

- backend sends a confirmation email
- the email contains a link to `GET /auth/confirm?token=...`

Expected result:

- account becomes confirmed
- next required step is DigiLocker

### 4. DigiLocker Verification

Choose one:

- `aadhaar`
- `passport`

What happens:

- app calls `/digilocker/request`
- app uses the returned `oauth_state` as the mock consent code
- app calls `/digilocker/verify`

Expected result:

- user is marked DigiLocker verified
- app continues to gig account connection

### 5. Connect Gig Account

Use:

```text
Platform: Swiggy or Zomato
Worker ID: SWG123 or ZMT123
```

What happens:

- backend stores the gig account
- 30 days of income data are generated automatically

Expected result:

- account connected successfully
- income history becomes available immediately

### 6. First Login Verification

On the first password login after onboarding:

- backend returns a first-login challenge
- user chooses `email` or `phone`
- OTP is sent only to that selected channel

Expected result:

- after OTP verification, the access token is returned
- later logins skip this first-login challenge

## Path B: Seeded Persona Story

All demo persona users share the same password:

```text
Demo@1234
```

Recommended actor picks:

- `good_actor` for a genuine disruption story
- `bad_actor` for fraud-aware rejection
- `premium_success` for the full premium-to-payout success story

Best quick walkthrough:

1. Log in as `good_actor`
2. Open `Home`
3. explain current risk
4. open `Insurance`
5. explain premium and coverage
6. open `Claims`
7. explain fraud and payout readiness

Then compare with:

1. Log in as `bad_actor`
2. show lower disruption support
3. explain why the system becomes more cautious

## Path C: Live Pipeline Demo

This is the strongest stage demo because it visually explains the whole product without requiring manual claim filing.

### Recommended Login

Use one of these:

- `premium_success`
- `good_actor`
- `bad_actor`

Choose `phone` OTP during login for speed.

### Step 1. Show Baseline State

Open the `Home` tab first.

Briefly explain:

- current environment
- current risk
- current auto claim state
- current payout state

Suggested line:

```text
The platform is already reading live working conditions and turning them into explainable insurance decisions.
```

### Step 2. Approved Path: Trigger Rain

1. In the `Demo Control Panel`, tap `Trigger Rain`
2. Wait for the `Live Demo Pipeline` to animate

Explain the flow:

1. `Environment`
   - rain, traffic, and AQI are elevated
2. `Risk Engine`
   - risk score increases and triggers activate
3. `Claim Engine`
   - the claim is auto-triggered from disruption plus loss
4. `Fraud Engine`
   - the story is consistent, so fraud stays acceptable
5. `Payout Engine`
   - payout is credited or shown as completed

Suggested line:

```text
This is parametric protection. The worker does not file a claim manually. The platform detects disruption, validates it, and acts automatically.
```

### Step 3. Fraud Path: Trigger Fraud

1. Tap `Trigger Fraud`
2. Wait for the pipeline to update

Explain:

- disruption support is weak
- the claim story and the environment no longer align
- fraud signals rise
- payout is blocked or skipped

Suggested line:

```text
The same system that helps honest workers quickly also protects the insurer from unsupported payouts.
```

### Step 4. Reset

1. Tap `Reset`
2. Confirm the dashboard returns to normal live or seeded behavior

Use this to transition into the admin dashboard or actor-based explanation.

## Admin Dashboard Walkthrough

After the worker story, go back to the role selection screen and choose `Login as Insurer`.

Use:

```text
Email: admin@gigshield.com
Password: admin123
```

Show:

- system health
- fraud intelligence
- financial health
- predictions
- recommendations

Suggested line:

```text
The insurer sees the same underlying system from the control side: fraud, payouts, loss ratio, and forward-looking risk.
```

## Suggested Judge Sequence

Use this order for the cleanest live presentation.

### Flow 1: Worker Live Story

1. Log in as worker
2. Open `Home`
3. Show the `Demo Control Panel`
4. Tap `Trigger Rain`
5. Explain the animated pipeline
6. Open `Insurance`
7. Open `Claims`

### Flow 2: Fraud-Aware Contrast

1. Return to `Home`
2. Tap `Trigger Fraud`
3. Explain fraud signals and payout block

### Flow 3: Insurer View

1. Return to role selection
2. Log in as insurer
3. Show admin analytics and predictions

## Flawless Demo Checklist

Use this right before you present.

### Technical Checklist

1. Start backend and confirm `/health`
2. Confirm correct LAN IP in the app
3. Confirm worker login works
4. Confirm admin login works
5. Confirm `Home` and `Insurance` load
6. Confirm one demo actor is already past the OTP friction if possible

### Best Demo Order

1. Start with the worker Home tab
2. Trigger `Rain`
3. Explain the pipeline
4. Trigger `Fraud`
5. Explain the rejection path
6. Switch to insurer role
7. Show fraud, finance, and predictions

### Recovery Plan

If something goes wrong:

- If OTP is slow:
  - use a seeded actor and choose `phone` OTP
- If the network is unstable:
  - stay within an already logged-in session
- If the payout path does not appear:
  - explain that fraud and policy gates intentionally stop unsupported payouts
- If admin is slow:
  - finish the worker story first, then retry the insurer view

## Notes

- The app's onboarding flow is stricter than older docs:
  - email confirmation is expected
  - DigiLocker is mandatory
  - first login uses a one-time second-step verification
- Connecting a gig account generates fresh mock income history.
- The cleanest demo location remains `Chennai`.
- If you reseed demo data, the same demo users are refreshed.
