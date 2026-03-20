# Gig Insurance Demo Walkthrough

This guide explains the demo users seeded by `backend/scripts/seed_demo_data.py`, what each user scenario represents, and what values to enter in the app to trigger the intended flows.

## Before You Start

1. Start the backend:

```bash
cd backend
python main.py
```

2. Seed the demo users:

```bash
python scripts/seed_demo_data.py
```

3. Start the Flutter app and point it to your backend base URL.

## Common App Inputs

These values are reused across most flows.

### Gig Account Connection

Use either of these platforms:

- `Swiggy`
- `Zomato`

Sample partner IDs you can type:

- `SWG-PERFECT-001`
- `ZMT-FRAUD-002`
- `SWG-INSUFF-003`
- `ZMT-NORMAL-004`
- `SWG-EDGE-005`

### Bank Linking

Sample bank values to type in the app:

```text
Account Number: 123456789012
IFSC: HDFC0001234
```

The backend mock bank accepts demo-format values like the above.

### Location for Risk / Claim

Use Chennai for the cleanest demo:

```text
Latitude: 13.0827
Longitude: 80.2707
City: Chennai
```

If GPS is enabled on the device and you are elsewhere, the app will use the live location instead.

## Demo Users

All seeded users use the same password:

```text
securePass123
```

### 1. Perfect User

Purpose:

- Approved claim
- Strong weekly income drop
- Same city work pattern
- Rain disruption week

Login:

```text
Email: perfect_user@test.com
Password: securePass123
```

DigiLocker:

```text
Name: Perfect User
Document Type: aadhaar
Document Number: 013456789012
```

Expected outcome:

- DigiLocker verification succeeds
- Risk shows meaningful disruption
- Premium can be viewed and paid
- Claim should be approved after policy-window checks
- Support chatbot can explain approved status

Recommended walkthrough:

1. Log in as `perfect_user@test.com`
2. Open `Verify Identity`
3. Enter:

```text
Document Type: aadhaar
Document Number: 013456789012
Name: Perfect User
```

4. Connect gig account:

```text
Platform: Swiggy
Partner ID: SWG-PERFECT-001
```

5. Link bank:

```text
Account Number: 123456789012
IFSC: HDFC0001234
```

6. View Risk tab with GPS enabled
7. Go to AI Engine / Premium and pay premium
8. Go to Claim flow
9. Expected result: `APPROVED` with payout

### 2. Fraud User

Purpose:

- Fraud rejection scenario
- Claims rain while weather pattern does not support it
- Income remains too healthy

Login:

```text
Email: fraud_user@test.com
Password: securePass123
```

DigiLocker:

```text
Name: Fraud User
Document Type: aadhaar
Document Number: 023456789012
```

Expected outcome:

- DigiLocker succeeds
- Claim gets rejected
- Fraud reasons should mention weather mismatch / healthy activity
- Support chatbot should explain rejection

Recommended walkthrough:

1. Log in as `fraud_user@test.com`
2. Verify identity with:

```text
Document Type: aadhaar
Document Number: 023456789012
Name: Fraud User
```

3. Connect gig account:

```text
Platform: Zomato
Partner ID: ZMT-FRAUD-002
```

4. Link bank
5. Open Claim flow after viewing risk
6. Expected result: `REJECTED`
7. Open support chat and ask:

```text
Why was my claim rejected?
```

Expected chatbot behavior:

- explains that the claim does not match weather / loss signals

### 3. Insufficient Data User

Purpose:

- Too little gig history
- No valid claim eligibility
- Demonstrates incomplete profile / early-stage user

Login:

```text
Email: insufficient_user@test.com
Password: securePass123
```

DigiLocker:

```text
Name: Insufficient Data User
Document Type: aadhaar
Document Number: 033456789012
```

Expected outcome:

- Only a few gig records exist
- Eligibility checks should fail
- Premium / claim flow should not look healthy

Recommended walkthrough:

1. Log in as `insufficient_user@test.com`
2. Verify identity with:

```text
Document Type: aadhaar
Document Number: 033456789012
Name: Insufficient Data User
```

3. Connect gig account:

```text
Platform: Swiggy
Partner ID: SWG-INSUFF-003
```

4. Open Earnings / Risk tabs
5. Open Claim flow
6. Expected result:

- claim blocked or rejected
- reason should mention insufficient data / eligibility failure

### 4. Normal Week User

Purpose:

- Stable earnings
- No real disruption
- No valid payout event

Login:

```text
Email: normal_week_user@test.com
Password: securePass123
```

DigiLocker:

```text
Name: Normal Week User
Document Type: aadhaar
Document Number: 043456789012
```

Expected outcome:

- Risk data works
- Premium can be viewed
- Claim should be rejected because there is no eligible weekly loss

Recommended walkthrough:

1. Log in as `normal_week_user@test.com`
2. Verify identity:

```text
Document Type: aadhaar
Document Number: 043456789012
Name: Normal Week User
```

3. Connect gig account:

```text
Platform: Zomato
Partner ID: ZMT-NORMAL-004
```

4. Link bank
5. Open Claim flow
6. Expected result: `REJECTED`
7. Likely reason:

- `No eligible weekly loss detected`

### 5. Escalation User

Purpose:

- Borderline fraud / inconsistent signals
- Partial disruption
- Manual review scenario

Login:

```text
Email: escalation_user@test.com
Password: securePass123
```

DigiLocker:

```text
Name: Escalation User
Document Type: aadhaar
Document Number: 053456789012
```

Expected outcome:

- Mixed city / disruption signals
- Claim may go to `NEEDS_REVIEW`
- Support chatbot becomes important here

Recommended walkthrough:

1. Log in as `escalation_user@test.com`
2. Verify identity:

```text
Document Type: aadhaar
Document Number: 053456789012
Name: Escalation User
```

3. Connect gig account:

```text
Platform: Swiggy
Partner ID: SWG-EDGE-005
```

4. Link bank
5. Open Claim flow
6. Expected result:

- `NEEDS_REVIEW` or a borderline fraud outcome

7. Open support chat and ask:

```text
What should I do next?
```

Expected chatbot behavior:

- explains that the claim needs manual review
- suggests checking location consistency and disruption proof

## Suggested Judge Demo Sequence

If you need a polished demo flow, use this order:

### Flow A — Complete Happy Path

Use `perfect_user@test.com`

1. Log in
2. Verify identity
3. Connect gig account
4. View Home, Risk, and Earnings
5. Link bank
6. Pay premium
7. Trigger claim
8. Show approved payout

### Flow B — Fraud Rejection

Use `fraud_user@test.com`

1. Log in
2. Open Claim flow
3. Show rejection
4. Open support chat
5. Ask why claim was rejected

### Flow C — Insufficient Data

Use `insufficient_user@test.com`

1. Log in
2. Open Earnings / Claim
3. Show eligibility failure

### Flow D — No Loss, No Claim

Use `normal_week_user@test.com`

1. Log in
2. Show stable earnings
3. Trigger claim
4. Show rejection because there is no valid weekly loss

### Flow E — Escalation / Review

Use `escalation_user@test.com`

1. Log in
2. Open AI Engine / Claim
3. Show borderline or review outcome
4. Open support chat for escalation guidance

## Notes

- All users are seeded as DigiLocker-verifiable users.
- All demo users share the same password: `securePass123`
- If you rerun `seed_demo_data.py`, the same accounts will be refreshed.
- Connecting the gig account in the app will also trigger fresh mock gig data generation through the backend.
- The cleanest demo city remains `Chennai`.
