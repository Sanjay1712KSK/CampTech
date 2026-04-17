# Live Demo Runbook

Use this as the operator checklist during the actual presentation.

## 1. Pre-Demo Setup

Complete these before the audience arrives.

1. Start the backend:

```bash
cd backend
python main.py
```

2. Verify health:

```text
http://<your-laptop-ip>:8000/health
```

3. Launch the Flutter app on the phone with the same IP.

4. Confirm:

- worker login works
- admin login works
- Home dashboard loads
- Insurance page loads
- phone and laptop are on the same Wi-Fi

## 2. Best Accounts To Use

Worker:

- `premium_success / Demo@1234`
- fallback: `good_actor / Demo@1234`
- fraud story: `bad_actor / Demo@1234`

Admin:

- `admin@gigshield.com / admin123`

## 3. Recommended Demo Order

### Worker Story

1. Open the app
2. Choose `Login as Worker`
3. Log in
4. Choose `phone` OTP if prompted
5. Land on `Home`

### Live Pipeline Story

1. Show the `Demo Control Panel`
2. Tap `Trigger Rain`
3. Explain:
   - Environment changed
   - Risk increased
   - Claim auto-triggered
   - Fraud approved
   - Payout credited

### Fraud Story

1. Tap `Trigger Fraud`
2. Explain:
   - environment support is weak
   - fraud signals rise
   - payout is blocked

### Explainability Story

1. Open `Insurance`
2. Show engine cards and premium explanation
3. Open `Claims`
4. Show fraud and payout outcome

### Insurer Story

1. Return to role selection
2. Choose `Login as Insurer`
3. Log in
4. Show:
   - system health
   - fraud intelligence
   - predictions
   - recommendations

## 4. Best Talk Track

Use this short narrative:

```text
GigShield is a real-time parametric insurance platform for gig workers.
It reads disruption signals like rain, air quality, and traffic, converts them into explainable risk, triggers claims automatically when real loss appears, checks fraud in real time, and credits payout instantly when the case is valid.
```

For the fraud moment:

```text
The same automation that protects honest workers also protects the insurer. If the disruption evidence and the claim story do not match, the payout is stopped.
```

For the admin moment:

```text
The insurer dashboard is the control center. It shows not just metrics, but fraud pressure, financial health, and forward-looking predictions.
```

## 5. Recovery Plan

If something goes wrong:

- If OTP is slow:
  - use a seeded actor
  - choose `phone` OTP
- If the app cannot reach backend:
  - recheck the laptop IP
  - confirm both devices are on the same Wi-Fi
- If the backend is slow:
  - refresh once
  - stay inside the already logged-in worker session
- If payout is skipped:
  - explain that the policy and fraud gates are intentionally protecting the system

## 6. Finish Strong

End with this contrast:

- honest worker -> auto protection
- suspicious claim -> fraud rejection
- insurer -> full control and insight
