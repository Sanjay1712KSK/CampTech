# Perfect Demo Script

This is the stage-ready script for demonstrating GigShield flawlessly from start to finish.

It is designed for a live presentation where you want to show:

- worker onboarding and trust
- real-time disruption intelligence
- automatic claim triggering
- fraud-aware decisioning
- instant payout
- insurer-side analytics

## Demo Goal

By the end of the demo, the audience should understand this full story:

`Environment -> Risk -> Claim -> Fraud -> Payout`

They should clearly see that the product is:

- real-time
- explainable
- automatic
- fraud-aware
- useful to both workers and insurers

## Pre-Demo Setup

Complete this before the presentation starts.

### Backend

1. Open terminal.
2. Start backend:

```bash
cd backend
python main.py
```

3. Confirm health:

```text
http://<your-laptop-ip>:8000/health
```

Expected:

```json
{"status":"ok"}
```

### App

1. Ensure phone and laptop are on the same Wi-Fi.
2. Launch the Flutter app on the phone using the same backend IP.
3. Confirm the Home dashboard opens.

### Final Safety Checks

Before going on stage, verify:

- worker login works
- admin login works
- Home tab loads
- Insurance tab loads
- Claims tab loads
- Demo Control Panel is visible on Home
- Live Demo Pipeline is visible after triggering a scenario

## Best Accounts To Use

### Worker Success Story

Use:

```text
Username: premium_success
Password: Demo@1234
```

Fallback:

```text
Username: good_actor
Password: Demo@1234
```

### Worker Fraud Story

Use:

```text
Username: bad_actor
Password: Demo@1234
```

### Admin

Use:

```text
Email: admin@gigshield.com
Password: admin123
```

## Recommended Demo Order

Use this sequence exactly.

1. Worker login
2. Worker Home dashboard
3. Trigger approved live pipeline
4. Explain Insurance page
5. Explain Claims page
6. Trigger fraud live pipeline
7. Switch to insurer dashboard
8. Show admin insights

This keeps the story smooth and easy to follow.

## Step-By-Step Demo Script

## Part 1: Entry And Role Selection

### What To Do

1. Open the app.
2. Pause briefly on the role selection screen.

### What To Say

```text
GigShield supports two perspectives in the same platform: the worker who needs protection, and the insurer who needs control, explainability, and fraud resistance.
```

3. Tap `Login as Worker`.

## Part 2: Worker Login

### What To Do

1. Log in as `premium_success` or `good_actor`.
2. If asked for OTP channel, choose `phone`.
3. Complete OTP and enter the app.

### What To Say

```text
I’m starting from the worker side, where the system continuously monitors real operating conditions and translates them into protection decisions.
```

## Part 3: Home Dashboard Baseline

### What To Do

On the `Home` tab, point out:

- current environment
- risk state
- coverage state
- trust and security section
- auto claim and payout section

### What To Say

```text
This dashboard is designed to answer four simple worker questions: what is happening, why it is happening, how it affects income, and what the system is doing automatically.
```

Then say:

```text
Before triggering anything manually for the demo, the platform is already reading live conditions like weather, AQI, and traffic.
```

## Part 4: Trigger The Success Story

### What To Do

1. Stay on the `Home` tab.
2. In `Demo Control Panel`, tap `Trigger Rain`.
3. Wait for the `Live Demo Pipeline` to animate.

### What To Say

```text
Now I’m simulating a real disruption scenario. Watch how the entire pipeline responds automatically.
```

## Part 5: Explain The Animated Pipeline

Go step by step as the cards appear.

### 1. Environment

### What To Point At

- rain
- traffic
- AQI

### What To Say

```text
The system first detects severe working conditions from environment signals. In this case, heavy rain and congestion increase operational disruption.
```

### 2. Risk Engine

### What To Point At

- risk score
- risk level
- triggers

### What To Say

```text
The risk engine converts those raw signals into explainable risk. It does not just label the day as bad. It shows why risk is high and which triggers are active.
```

### 3. Claim Engine

### What To Point At

- claim triggered
- loss
- explanation

### What To Say

```text
This is a zero-touch claim engine. The worker does not manually submit proof. If disruption and loss thresholds are crossed, the system generates the claim automatically.
```

### 4. Fraud Engine

### What To Point At

- fraud score
- decision
- signals

### What To Say

```text
Before any money moves, the fraud engine validates the story using device trust, location consistency, behavior, and context matching.
```

### 5. Payout Engine

### What To Point At

- payout amount
- transaction id
- status

### What To Say

```text
Once the claim passes fraud validation, the payout engine processes the transfer instantly and records the transaction trail.
```

## Part 6: Summarize The Worker Story

### What To Say

```text
So the full story is: disruption is detected, risk increases, claim is triggered automatically, fraud is checked, and payout is credited without manual paperwork.
```

## Part 7: Open Insurance Page

### What To Do

Open `Insurance`.

### What To Show

- weekly premium
- coverage
- explainable engine cards
- policy state
- fraud visibility
- payout readiness

### What To Say

```text
This page explains the insurance logic itself. It shows the engines, the inputs they use, what they do, and the output they generate, so the system feels transparent instead of black-box.
```

## Part 8: Open Claims Page

### What To Do

Open `Claims`.

### What To Show

- claim status
- payout state
- fraud outcome
- trust / blockchain cues if visible

### What To Say

```text
The worker can see not only the outcome, but also the reasoning. That is important in insurance, because trust depends on clarity.
```

## Part 9: Trigger The Fraud Story

### What To Do

1. Go back to `Home`.
2. In `Demo Control Panel`, tap `Trigger Fraud`.

### What To Say

```text
Now I’ll show the opposite side of the platform: protecting the insurer from unsupported or suspicious claim behavior.
```

## Part 10: Explain The Fraud Outcome

### What To Point At

- lower disruption support
- fraud signals
- rejected or blocked payout outcome

### What To Say

```text
Here the environment support is weak, but the claim path looks suspicious. The fraud engine detects that mismatch and prevents payout. This protects the system without punishing genuine workers under real disruption.
```

## Part 11: Switch To Insurer Role

### What To Do

1. Return to role selection.
2. Tap `Login as Insurer`.
3. Log in with admin credentials.

### What To Say

```text
Now I’ll show the same platform from the insurer’s perspective.
```

## Part 12: Admin Dashboard

### What To Show

Walk through:

- System Health
- Fraud Intelligence
- Risk + Claim Trends
- Predictions
- Smart Insights
- Recommendations

### What To Say

```text
This is not just an analytics dashboard. It is an insurer control panel. It shows fraud pressure, financial health, payout exposure, and forward-looking predictions so the insurer can make decisions, not just read metrics.
```

Then point to recommendations and say:

```text
The system is not only reactive. It also helps the insurer decide where to adjust pricing, where to watch for fraud, and where future claims pressure may rise.
```

## Strong Closing

End with this:

```text
GigShield brings together real-time disruption sensing, explainable underwriting, automatic claims, fraud intelligence, and instant payout in one connected platform. It protects honest workers quickly while still giving insurers the control they need.
```

## Best Timing Plan

If you have about 5 to 7 minutes:

### 1 minute

- role selection
- worker login

### 2 minutes

- Home dashboard baseline
- Trigger Rain
- explain pipeline

### 1 minute

- Insurance page
- Claims page

### 1 minute

- Trigger Fraud
- explain rejection

### 1 to 2 minutes

- insurer dashboard
- close with value proposition

## Backup Plan If Something Fails

### If OTP Is Slow

Use a seeded persona and choose `phone` OTP.

### If Backend Connection Fails

Check:

- laptop IP
- same Wi-Fi
- backend terminal still running

### If A Page Loads Slowly

Refresh once and continue.

### If Payout Does Not Show

Say:

```text
The system intentionally blocks payout when policy state or fraud conditions are not satisfied. That guardrail is part of the product.
```

## Final Pre-Stage Checklist

Read this right before presenting.

1. Backend running
2. Correct Wi-Fi IP
3. Phone connected
4. Worker login tested
5. Admin login tested
6. Home tab loads
7. Insurance tab loads
8. Claims tab loads
9. Trigger Rain tested once
10. Trigger Fraud tested once

If all ten are true, the demo is ready.
