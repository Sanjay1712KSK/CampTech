# Actor Demo Guide

This guide explains how to use the simulated demo users in the app and what each actor is designed to show.

## Before You Start

1. Start the backend.
2. Run the simulation input route once:

```http
POST /simulate/input
Content-Type: application/json

{
  "enable_simulation": true,
  "regenerate_income": true,
  "days": 30
}
```

3. Make sure the app points to the live backend URL on your laptop.
4. Open the app on the phone.

Important notes:

- The simulation layer only creates input data.
- Risk, premium, claim, fraud, and payout results are still produced by the real engines.
- These users are already created as confirmed, DigiLocker-verified, and gig-connected.
- Login still asks for OTP on `email` or `phone`.
- For demo ease, choose `phone` OTP during login because the phone OTP is shown in the app flow.
- Demo actor emails use the same Brevo SMTP flow as normal users.
- If you choose `email`, the OTP is sent to the actor's configured inbox, while `phone` remains the easier demo path because the mock OTP is shown in the UI.
- The Home tab now includes a `Demo Control Panel` and a `Live Demo Pipeline` section for stage demos.

## Demo Login Credentials

Default password for all demo actors:

```text
Demo@1234
```

### Good Actor

- Username: `good_actor`
- Email: `good.actor@gigshield.demo`
- Phone: `+919100000001`

### Bad Actor

- Username: `bad_actor`
- Email: `bad.actor@gigshield.demo`
- Phone: `+919100000002`

### Edge Case

- Username: `edge_case`
- Email: `edge.case@gigshield.demo`
- Phone: `+919100000003`

### Low Risk

- Username: `low_risk`
- Email: `low.risk@gigshield.demo`
- Phone: `+919100000004`

### Premium Success

- Username: `premium_success`
- Email: `suresh.patel@gigshield.demo`
- Phone: `+919100000005`

You can log in with any one of:

- username
- email
- phone number

## App Navigation

The app now has these main tabs:

1. `Home`
   Shows current risk in simple language.
2. `Earnings`
   Shows gig income trends and work pattern insights.
3. `Insurance`
   Shows premium, coverage, pricing explanation, bank linking, and premium payment.
4. `Claims`
   Shows claim status, fraud score, payout, and blockchain indicator.
5. `Profile`
   Remains unchanged.

## Recommended Demo Flow

For each actor, use this walkthrough:

1. Log in with one of the credentials above.
2. Choose `phone` for the login OTP.
3. Open `Home` to explain current risk.
4. Open `Earnings` to show 30-day income behavior.
5. Open `Insurance` to show how risk affects premium and coverage.
6. If the bank is not linked, link it.
7. Pay weekly premium to show policy creation.
8. Open `Claims` to show claim status, fraud logic, and blockchain record behavior.

## Live Pipeline Demo Controls

The worker `Home` tab now supports a cleaner live stage flow.

### Trigger Rain

Use this when you want to show:

- severe disruption
- increased risk
- zero-touch claim triggering
- approved fraud decision
- payout success

Best actor:

- `premium_success`
- `good_actor`

### Trigger Fraud

Use this when you want to show:

- weak disruption evidence
- mismatch between claim story and environment
- fraud signals rising
- payout block or rejection path

Best actor:

- `bad_actor`

### Reset

Use this to return to the actor's normal seeded state before moving to the next story.

Important claim note:

- A payout requires a claimable policy window and real trigger-based loss conditions.
- If a claim is not yet eligible, the Claims tab still demonstrates the engine reasoning and status handling.

## What Each Actor Demonstrates

## Good Actor

### Persona

- Demo name: `Arjun Kumar`
- Persona: `Trusted Professional`
- Profile: consistent, disciplined delivery partner

### Behavior

- works daily for around 6 to 8 hours
- pays premium every week
- stable income pattern

### What this actor means

This user represents a genuine worker facing real disruption.

### Simulated inputs

- high rain
- high traffic
- moderately elevated AQI
- higher income drop pattern across the last 30 days
- steady work pattern

### What you should see

#### Home

- higher risk level, often `HIGH`
- stronger expected income loss
- triggers like rain and traffic
- clear reasons such as weather and congestion

#### Earnings

- visible drop days
- stronger variation between best and weak earning days
- disruption-linked income dips

#### Insurance

- higher premium than low-risk users
- active triggers shown in pricing context
- explanation that pricing is linked to live disruption

#### Claims

- this is the best actor to demonstrate a believable approval path once claim timing is valid
- fraud score should usually look lower than bad_actor
- if the policy window is not yet claimable, the screen still shows the correct guarded behavior

### Demo scenario

- heavy rain
- high traffic
- real disruption

### System behavior

- risk -> `HIGH`
- eligible for insurance
- premium -> paid
- claim -> auto-detected when claim conditions are valid
- fraud -> low

### Outcome

- auto payout path is the intended story for this actor
- bank can be credited once the policy and claim timing conditions are satisfied

### Demo line

Arjun is a consistent worker who pays his weekly premium on time. When a real disruption occurs, our system automatically detects income loss and credits his payout without any manual claim.

### Why this actor matters

This is the best example of the intended product story:

Environment -> Risk -> Premium -> Claim -> Payout

## Bad Actor

### Persona

- Demo name: `Ravi Sharma`
- Persona: `System Gamer`
- Profile: irregular worker who tries to exploit the system

### Behavior

- inconsistent work pattern
- no real disruption
- claims high loss

### What this actor means

This user is meant to represent suspicious or weakly supported claims.

### Simulated inputs

- normal weather
- normal traffic
- low disruption
- income pattern that does not naturally support disruption-based loss
- anomalous behavior profile

### What you should see

#### Home

- lower or calmer risk than good_actor
- fewer active triggers
- weaker disruption explanation

#### Earnings

- income history looks more stable
- fewer real disruption-linked drops

#### Insurance

- lower or moderate premium
- fewer trigger adjustments

#### Claims

- strongest actor to explain fraud logic
- if this user tries to claim under calm conditions, the claim engine should lean toward rejection or a fraud concern
- this actor helps show why the system does not blindly pay claims

### Demo scenario

- normal weather
- no meaningful triggers
- fake loss story

### System behavior

- risk -> `LOW`
- no triggers
- ML detects anomaly

### Outcome

- claim rejected is the intended story
- fraud score should appear high relative to the other actors

### Demo line

Ravi attempts to claim high loss without any real disruption. Our system detects this mismatch using AI and prevents fraudulent payouts.

### Why this actor matters

This is the best actor for explaining:

- trigger validation
- anomaly-based fraud score
- predicted loss vs actual loss mismatch
- behavior-based review

## Edge Case

### Persona

- Demo name: `Meena Das`
- Persona: `Uncertain Case`
- Profile: semi-consistent worker with mixed signal quality

### Behavior

- moderate activity
- slight income fluctuation

### What this actor means

This user represents an ambiguous middle case.

### Simulated inputs

- medium rain or traffic
- moderate disruption
- mixed income pattern
- variable behavior profile

### What you should see

#### Home

- often `MEDIUM` risk
- balanced explanation instead of extreme risk
- some but not always severe triggers

#### Earnings

- mixed stability
- some low days, some strong days
- not as clearly disrupted as good_actor

#### Insurance

- middle-range premium
- moderate coverage story
- good example for explaining that the pricing is adaptive, not fixed

#### Claims

- useful for explaining flagged or borderline review behavior
- this actor is good for showing that the system handles gray areas instead of just approve/reject extremes

### Demo scenario

- mild rain
- moderate traffic

### System behavior

- risk -> `MEDIUM`
- loss -> borderline
- fraud score -> medium

### Outcome

- this actor is best used for a flagged or review-needed explanation

### Demo line

Meena represents the real-world gray zone. Conditions are not fully normal and not fully severe, so the system explains the risk, prices carefully, and can flag the case for review instead of making a blind decision.

### Why this actor matters

This is the best actor for explaining:

- medium-risk pricing
- borderline claim evaluation
- real-world ambiguity in insurtech decisions

## Low Risk

### Persona

- Demo name: `Karthik Nair`
- Persona: `Normal Day`
- Profile: stable working conditions

### What this actor means

This user represents calm, favorable working conditions.

### Simulated inputs

- little or no rain
- low traffic
- cleaner air
- relatively stable income
- low-risk work pattern

### What you should see

#### Home

- low risk
- lower expected income loss
- few or no active triggers

#### Earnings

- more stable earnings pattern
- fewer disruption days

#### Insurance

- lower premium
- simple explanation with minimal trigger impact
- best actor for showing that the system rewards safer conditions

#### Claims

- likely weaker claim support under current conditions
- useful for showing why not every user should expect a payout

### Demo scenario

- no disruption

### System behavior

- risk -> `LOW`
- insurance may not feel necessary
- premium should stay low

### Outcome

- no claim story
- low premium story

### Demo line

Karthik shows the fairness side of the platform. On calm days with stable work conditions, risk remains low, premium stays lower, and the system avoids unnecessary claim or payout behavior.

### Why this actor matters

This is the best actor for explaining:

- fair pricing under calm conditions
- low-risk product behavior
- premium differences across users

## Premium Success Persona

### Persona

- Demo name: `Suresh Patel`
- Persona: `Premium Success User`
- Profile: paid user who experiences a real disruption after being protected

### Scenario

- paid last week premium
- rain disruption occurred

### Intended system story

- premium paid -> `Rs 150`
- payout received -> `Rs 320`
- auto payout
- blockchain record stored
- bank credited

### Simulated login

- Username: `premium_success`
- Email: `suresh.patel@gigshield.demo`
- Phone: `+919100000005`

### What is pre-seeded for this actor

- bank account already linked
- premium payment already recorded for the previous policy week
- completed policy week already exists
- approved claim already present
- payout credited today
- blockchain policy, claim, and payout records already written

### Demo line

Suresh shows the full value of the system. After paying his weekly premium, a real disruption affects his earnings, and the platform automatically validates the event, records it securely, and credits the payout.

## How To Explain The System During Demo

Use this simple story:

1. We simulate only the worker inputs.
   Income, work pattern, and local conditions are seeded.
2. The risk engine reads those live inputs.
   It turns weather, traffic, and air quality into expected disruption.
3. The premium engine uses the real risk result.
   Premium is not mocked separately.
4. Policy is created when the user pays the premium.
5. The claim engine checks loss, triggers, and fraud signals.
6. The ML layer compares predicted loss with actual behavior.
7. Blockchain records are written through the adapter for trust and auditability.

## Best Actor-To-Feature Mapping

- Use `good_actor` to explain real disruption and strong insurtech value.
- Use `bad_actor` to explain fraud detection and controlled payouts.
- Use `edge_case` to explain explainable AI in uncertain conditions.
- Use `low_risk` to explain lower premium and stable earnings.
- Use `premium_success` to explain the complete premium-to-payout success story.

## Quick Demo Script

### Demo 1: Honest worker under disruption

- Log in as `good_actor`
- Show `Home`
- Tap `Trigger Rain`
- Explain high rain and traffic
- Explain the animated `Live Demo Pipeline`
- Open `Insurance`
- Explain why premium is higher
- Open `Claims`
- Explain why this user is the strongest candidate for a valid claim path

### Demo 2: Fraud-aware system

- Log in as `bad_actor`
- Show `Home`
- Tap `Trigger Fraud`
- Explain that conditions are mostly normal
- Explain the fraud signals in the `Live Demo Pipeline`
- Open `Claims`
- Explain why the fraud engine should be more cautious here

### Demo 3: Fair pricing for safer users

- Log in as `low_risk`
- Show `Home`
- Show `Insurance`
- Explain lower risk and lower premium

### Demo 4: Gray-zone intelligence

- Log in as `edge_case`
- Walk through all tabs
- Explain medium risk, moderate premium, and explainable review behavior
