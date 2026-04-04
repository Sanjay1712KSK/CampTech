# GigSHIELD By Team CampTech

Real-time, explainable income protection for gig workers.

This repository contains a full-stack insurtech prototype built for the DevTrails hackathon. It combines a Flutter mobile-first client with a FastAPI backend to simulate how a gig worker's live operating conditions can flow through a connected insurance pipeline:

`Environment -> Risk -> Premium -> Policy -> Claim -> Fraud -> Payout -> Blockchain Record`

The product was originally started under the working name `GigShield` in the codebase. For Phase 2 positioning and demo storytelling, the project is presented as `IncomePulse`.

## Why This Project Exists

Gig workers face day-to-day income volatility caused by real-world disruptions:

- rain and storms reduce delivery capacity
- traffic slows order completion
- AQI and heat affect safe working hours
- weekly earnings can swing sharply without any protection layer

Traditional insurance products do not fit this reality well. They are usually:

- not hyperlocal
- not explainable
- not aligned to weekly cash flow
- slow to validate disruption-led income loss

GigSHIELD is designed as an intelligent, modular, and explainable protection system for this exact problem space.

## Phase 2 Positioning

This prototype is intentionally designed to stand out from generic hackathon insurance demos in three ways:

1. It uses live environmental APIs for core decision-making.
2. It connects all major engines into one reusable pipeline instead of duplicating logic.
3. It demonstrates clearly different outcomes for different worker personas through the same backend logic.

The emphasis is not just on polished UI, but on:

- originality of system behavior
- explainability of decisions
- fairness for genuine workers
- resistance to bad claims
- end-to-end intelligence across onboarding, pricing, claims, and payout

## What Is Real-Time And What Is Mocked

### Real-Time Inputs

The core intelligence uses live environmental inputs:

- Weather via `Open-Meteo`
- AQI via `OpenWeather Air Pollution API`
- Traffic context via `OpenRouteService`

These signals are used by the actual backend engines to drive:

- risk scoring
- expected income loss
- premium pricing
- trigger activation
- claim reasoning

### Mocked Or Simulated Layers

Some integrations are intentionally mocked or adapter-based for demo practicality:

- SMS OTP delivery
- DigiLocker verification flow
- blockchain write target through a mock-first adapter
- persona seeding and simulation inputs
- gig platform connection as a simulated Swiggy/Zomato-style integration

Important: the simulation layer only injects inputs. It does not hardcode risk, premium, or claim outcomes. Those outputs still come from the real engines.

## System Overview

The platform has five major capabilities:

1. Secure onboarding for workers
2. Gig account connection and income history generation
3. Real-time environment and risk intelligence
4. Dynamic premium, policy, and claim automation
5. Adaptive fraud, ML learning, and blockchain-backed traceability

## Core Product Flow

1. User signs up
2. OTP verification is completed for contact channels
3. Email confirmation link activates the account
4. DigiLocker verification completes KYC
5. User connects a gig account
6. Gig income history is available
7. Live environment APIs feed the Risk Engine
8. Premium is generated directly from Risk Engine output
9. User pays weekly premium and policy is created
10. Disruption causes income loss
11. Claim Engine validates loss and fraud risk
12. Payout is issued when approved
13. Policy, claim, and payout records are written through the blockchain adapter

## Architecture

### Frontend

- Flutter
- Riverpod
- Geolocator
- Local authentication for biometric unlock on supported devices

Main UX surfaces:

- Home
- Earnings
- Insurance
- Claims
- Profile

### Backend

- FastAPI
- SQLAlchemy ORM
- SQLite for development
- PostgreSQL-ready production deployment
- JWT authentication
- bcrypt password hashing

### External APIs

- Open-Meteo
- OpenWeather Air Pollution
- OpenRouteService
- Mailtrap

## Local Vs Deployed OTP Behavior

The project now differentiates OTP behavior between local development and the deployed Render backend.

### Local backend

When you run the backend locally, the intended behavior remains strict:

- signup expects both email OTP and phone OTP
- forgot-password reset expects both email OTP and phone OTP
- the email OTP field should appear in the UI
- this is the recommended mode for full onboarding testing after cloning the repository

In local mode, email delivery is expected to work when your Mailtrap setup is valid.

### Deployed backend

The Render deployment currently has a resilience fallback enabled because Mailtrap delivery may fail intermittently in deployment.

- signup can continue with phone OTP if email OTP delivery fails
- forgot-password reset can continue with phone OTP if email OTP delivery fails
- the UI hides the email OTP field when the backend reports that email delivery failed
- login already supports choosing `email` or `phone`, so deployed usage should prefer `phone` when email is unreliable

This fallback is controlled by the backend environment variable:

- `EMAIL_OTP_OPTIONAL_ON_FAILURE=true` on Render

Local development does not need this flag enabled. By default, the backend keeps strict email+phone OTP behavior locally.

### ML / Intelligence Stack

- Heuristic + weighted decision models
- Anomaly-based fraud scoring
- Database-driven adaptive learning
- Regression-ready prediction hook

## Backend Engines

### 1. Environment Engine

Collects and normalizes:

- temperature
- humidity
- wind speed
- rain estimate
- AQI
- traffic index

It also supports:

- current conditions
- hourly forecast
- recent local comparison

Logic:

- pulls current and hourly weather data from Open-Meteo
- pulls AQI from OpenWeather
- derives traffic context from OpenRouteService
- normalizes everything into one environment snapshot:
  - temperature
  - humidity
  - wind speed
  - rain estimate
  - AQI
  - traffic index
- stores or compares this snapshot for hyperlocal analysis

### 2. Disruption Model

Transforms environmental conditions into operational effects:

- delivery capacity
- working hours factor

This is the bridge between weather data and delivery economics.

Logic:

- rain and traffic primarily reduce `delivery_capacity`
- AQI, heat, and wind primarily reduce `working_hours_factor`
- penalties are bounded using clamp functions so disruption stays interpretable
- the model exposes a factor breakdown:
  - rain penalty
  - traffic penalty
  - AQI penalty
  - heat penalty
  - wind penalty

### 3. Risk Engine

Turns environmental disruption into:

- risk score
- risk level
- expected income loss
- delivery efficiency
- time-slot risk
- predictive risk
- active parametric triggers
- reasons

This is the single source of disruption truth used by the rest of the system.

Logic:

- uses the normalized environment snapshot
- computes factor scores for:
  - rain
  - traffic
  - AQI
  - wind / heat
- computes disruption using the disruption model
- computes delivery efficiency using:
  - `efficiency_score = delivery_capacity * working_hours_factor`
- computes:
  - `expected_income_loss = 1 - efficiency_score`
- combines:
  - weighted environmental factors
  - expected income loss
  - hyperlocal multiplier
- outputs:
  - final risk score
  - risk level
  - triggers
  - reasons
  - recommendation

Current risk-score structure:

- 65% weighted environmental factor contribution
- 35% delivery-efficiency-derived income loss contribution
- hyperlocal risk then adjusts the final score within a bounded range

### 4. Hyperlocal Engine

Compares current conditions against recent local history to determine whether today's disruption is unusually severe.

Logic:

- compares current snapshot against recent local averages or snapshots
- increases confidence when disruption is significantly above local norm
- produces:
  - `hyper_local_risk`
  - a textual insight
  - a baseline comparison snapshot

### 5. Predictive Engine

Uses forecast data to estimate near-future risk trends, especially the next 6 hours.

Logic:

- reads hourly forecast from environment data
- estimates next-6-hour disruption severity
- classifies trend as:
  - increasing
  - decreasing
  - stable

### 6. Trigger Engine

Activates parametric triggers such as:

- `RAIN_TRIGGER`
- `TRAFFIC_TRIGGER`
- `AQI_TRIGGER`
- `HEAT_TRIGGER`
- `COMBINED_TRIGGER`

Logic:

- activates triggers when thresholds are crossed
- examples:
  - high rain -> `RAIN_TRIGGER`
  - heavy congestion -> `TRAFFIC_TRIGGER`
  - poor air quality -> `AQI_TRIGGER`
  - high heat -> `HEAT_TRIGGER`
- `COMBINED_TRIGGER` activates when multiple disruption drivers are simultaneously strong
- outputs overall trigger severity used later by the Premium Engine

### 7. Premium Engine

Strictly reuses Risk Engine output.

Inputs:

- baseline income
- risk score
- trigger severity
- active triggers

Outputs:

- weekly premium
- coverage
- explanation

No duplicate risk logic is used here.

Logic:

- calculates baseline income from recent top earning days
- computes:
  - `weekly_income = baseline_income * 7`
- reuses the Risk Engine result directly
- applies pricing:
  - `premium = weekly_income * risk_score * 0.07`
- applies adjustments:
  - high trigger severity increases premium
  - combined trigger applies another multiplier
- computes:
  - `coverage = weekly_income * 0.8`
- stores:
  - premium snapshot
  - linked risk context

### 8. Policy Engine

Creates weekly policy periods and links pricing context to the insured period.

Logic:

- creates 7-day policy windows
- ties premium payment to policy activation
- makes the system claim-aware by distinguishing:
  - active policy
  - completed claimable policy week
  - already settled claim period

### 9. Claim Engine

Reuses:

- Risk Engine
- Premium Engine
- gig income data
- policy context
- fraud logic
- ML learning hooks

It evaluates:

- expected income
- actual income
- disruption triggers
- fraud score
- payout eligibility

Logic:

- fetches the claimable policy
- gets expected income from baseline
- gets actual income from gig data
- calculates:
  - `loss = expected_income - actual_income`
- rejects when:
  - no completed policy week exists
  - no active triggers exist
  - no real loss exists
  - the week was already claimed and paid
- approved payout logic:
  - `payout = loss * 0.8`
  - capped by coverage when needed
- writes:
  - claim record
  - learning record
  - blockchain adapter record

### 10. Fraud / ML Layer

Uses anomaly-style logic, not heavy training infrastructure.

Signals include:

- predicted vs actual loss
- user behavior deviation
- trigger mismatch
- claim pattern consistency

It produces:

- fraud score
- confidence
- decision support for approve / flag / reject

Logic:

- starts from:
  - `predicted_loss = risk_score * baseline_income`
- compares predicted loss vs actual loss
- checks deviation from stored user behavior
- checks whether active triggers support the claim
- computes anomaly-oriented fraud score
- decision bands:
  - low score -> approve
  - medium score -> flag
  - high score -> reject

### Fraud Engine Design

The fraud engine is designed to be explainable rather than opaque.

It does not rely on one single binary check. Instead, it combines multiple fraud-relevant signals:

- predicted loss from the risk engine
- actual observed loss from gig income
- user behavior deviation from recent history
- trigger mismatch between claim story and environmental evidence
- policy and claim-window validity

This means fraudulent or unsupported claims are not rejected blindly. They are evaluated through a layered anomaly score that can:

- approve
- flag for caution
- reject

The system therefore protects both sides:

- honest workers are not punished by static rules
- insurers are not exposed to unsupported payouts

### 11. Adaptive Learning Layer

Stores and updates:

- model weights
- user behavior snapshots
- claim learning history

This makes the system ML-ready while staying hackathon-practical.

Logic:

- stores claim learning records after claim processing
- keeps model weights in the database rather than in a static config
- updates user behavior snapshots from:
  - average income
  - average loss
  - work pattern
  - city pattern
  - claim frequency
- updates factor weights using recent claim error patterns

This means the system can adapt which factors matter most over time, for example:

- if rain repeatedly explains real loss better than traffic, rain weight increases slightly
- if AQI becomes more important in loss outcomes, AQI weight rises in future scoring

Training only occurs when user settings allow model training.

### 12. ML Pipeline Used In The Engines

The project uses a lightweight database-driven ML pipeline rather than heavy model training infrastructure.

Pipeline steps:

1. Risk Engine calculates a risk score from environmental disruption.
2. Expected loss model estimates:
   - `predicted_loss = risk_score * baseline_income`
3. Claim Engine measures:
   - actual loss
   - payout outcome
4. Claim history stores:
   - predicted loss
   - actual loss
   - active triggers
   - fraud score
5. Adaptive layer updates:
   - model weights
   - user behavior
6. Future risk and fraud decisions reuse these updated signals.

This creates a closed learning loop:

`live environment -> decision -> claim outcome -> learning record -> updated weights -> better future decisions`

Optional ML hook:

- a lightweight regression-style hook exists for future model-backed efficiency prediction
- when unavailable, the system safely falls back to rule-based logic

## Why It Is Dynamic

This system is designed to behave differently as conditions change.

It is dynamic because:

- live weather, AQI, and traffic APIs continuously change the environment context
- risk is recalculated from current inputs rather than hardcoded categories
- premium reuses live risk output instead of static pricing slabs
- claim reasoning changes depending on:
  - trigger activation
  - actual income loss
  - policy state
  - user behavior pattern
- the simulation layer changes only the inputs, so the same backend logic produces different outcomes across personas
- adaptive learning updates model weights and user behavior snapshots over time

This allows the system to generate:

- different pricing for different risk conditions
- different claim decisions for different workers
- different fraud outcomes for different behavioral patterns

## Why It Is Fail-Safe

The system is intentionally guarded so that one failure or one missing condition does not break the product logic.

Fail-safe behaviors include:

- claims are blocked when no completed claimable policy week exists
- claims are blocked when no active disruption triggers exist
- duplicate already-paid claim weeks are blocked
- fraud scoring can flag cases instead of forcing a binary approve/reject
- blockchain writes happen through an adapter, so blockchain failure does not stop core business logic
- external API absence can fall back gracefully instead of crashing the entire flow
- SQLite is used locally, while the backend is already PostgreSQL-ready for deployment
- biometric and deep-link flows degrade safely for unsupported platforms such as web

This makes the platform more reliable in both demo and deployment scenarios.

### 12. Blockchain Adapter Layer

A pluggable adapter supports:

- mock mode for demos
- NBFLite-compatible future integration

It records:

- policies
- claims
- payouts

without blocking core business flows if the external chain is unavailable.

## Auth And Onboarding

The onboarding system is more than a login screen. It includes:

- signup with live username and email availability checks
- password strength validation
- OTP verification over email and phone
- email confirmation link
- mandatory DigiLocker verification
- login with identifier support:
  - email
  - username
  - phone
- user-selected second-step verification during login
- forgot password flow
- optional biometric unlock

This supports a more realistic fintech / insurtech onboarding story for the demo.

## Gig Connection And Income Layer

The backend simulates connecting gig platforms such as Swiggy and Zomato.

When connected, it generates realistic input data including:

- 30 days of earnings
- orders completed
- hours worked
- disruption type
- weather and traffic-linked loss markers

This data is then used by:

- baseline income calculation
- premium pricing
- claim logic
- user behavior analysis

## Persona Simulation Layer

To make the demo meaningful and dynamic, the system includes persona-driven input seeding.

Simulated actors:

- `good_actor`
- `bad_actor`
- `edge_case`
- `low_risk`
- `premium_success`

These personas differ in:

- environment severity
- work patterns
- risk profile
- premium story
- claim outcome
- fraud posture

This allows the exact same app and backend to produce different outcomes per worker instead of showing one generic flow.

See:

- [actor_demo_guide.md](backend/docs/demo/actor_demo_guide.md)

## Two Highlight Personas For Phase 2

### Ravi Sharma (`bad_actor`)

Represents the "system gamer" story.

- weak disruption evidence
- low trigger activation
- high anomaly signal
- rejected claim outcome

This persona demonstrates fraud awareness and payout restraint.

### Suresh Patel (`premium_success`)

Represents the "protected worker" story.

- premium already paid
- real weather anomaly
- approved claim already settled
- payout credited
- trusted transaction trail visible

This persona demonstrates the full insurance lifecycle working correctly.

## UI Design Direction

The app has been refactored into a more explainable, layman-friendly insurtech interface.

Main tabs:

- Home
- Earnings
- Insurance
- Claims
- Profile

Key UX goals:

- explain what is happening now
- explain why the system decided that
- show how risk affects money
- make claim and payout states visible
- surface trust through transaction and blockchain cues

The demo also includes persona-specific UI explanation banners so the story changes visibly across users.

## Visual Walkthrough

The screenshot library is available in [Demo/Screenshots](Demo/Screenshots) and is grouped into:

- `Real User`
- `Good Mock Up User`
- `Bad Mock Up User`

Below is a tighter visual walkthrough using the strongest screens only, so the README stays focused.

Screenshot note:

- the screens were captured on a Samsung Galaxy S20 Ultra
- exported images in this repository are portrait mobile captures
- most screenshot files are resized / compressed exports in an approximate range of `378-386 px` width and `845-855 px` height
- small dimension differences across files are due to cropping and export variation, not UI inconsistency

### Onboarding Flow

<table>
  <tr>
    <th>Sign Up</th>
    <th>Verify Contact Channels</th>
    <th>Email Confirmation</th>
    <th>DigiLocker Verification</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Real%20User/Sign%20Up%20Page.png" width="220" alt="Sign up page" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Verify%20Contact%20Channels.png" width="220" alt="Verify contact channels" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Email%20Confirmation%20Page.png" width="220" alt="Email confirmation page" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Digilocker%20Verification%20Mockup.png" width="220" alt="DigiLocker verification" /></td>
  </tr>
  <tr>
    <td>Registration form for a new worker account.</td>
    <td>Dual-channel verification across email and phone.</td>
    <td>Account activation step before full onboarding.</td>
    <td>Mandatory KYC stage before access to the main product.</td>
  </tr>
</table>

What this shows:

- registration and credential setup
- OTP verification across channels
- email confirmation
- DigiLocker completion

### Core Product Tabs

<table>
  <tr>
    <th>Home</th>
    <th>Earnings</th>
    <th>Insurance</th>
    <th>Claims</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Real%20User/Home%20Page%201%20Real%20User.png" width="220" alt="Home risk dashboard" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Earnings%201%20Real%20User.png" width="220" alt="Earnings dashboard" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Insurance%20Page%201%20Real%20User.png" width="220" alt="Insurance dashboard" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Claims%20Page%201%20Real%20User.png" width="220" alt="Claims dashboard" /></td>
  </tr>
  <tr>
    <td>Live disruption, risk, persona context, and system summary.</td>
    <td>Income trends, work patterns, and earning behavior.</td>
    <td>Premium, coverage, pricing logic, and payment flow.</td>
    <td>Claim status, fraud signals, payout, and trust layer.</td>
  </tr>
</table>

What this shows:

- Home tab focused on live disruption and risk
- Earnings tab focused on worker income behavior
- Insurance tab focused on premium and protection
- Claims tab focused on approval, fraud, payout, and trust

### Persona Views

#### Good Actor View

<table>
  <tr>
    <th>Good Actor Home</th>
    <th>Good Actor Insurance</th>
    <th>Good Actor Claims</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Home%20Page%201%20Mock%20Up%20User.png" width="240" alt="Good actor home" /></td>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Insurance%20Page%201%20Mock%20Up%20User.png" width="240" alt="Good actor insurance" /></td>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Claims%20Page%201%20Mock%20Up%20User.png" width="240" alt="Good actor claims" /></td>
  </tr>
  <tr>
    <td>Shows a genuine disruption-led high-risk story.</td>
    <td>Shows how live risk justifies meaningful protection pricing.</td>
    <td>Shows the credible insured-worker claim path.</td>
  </tr>
</table>

This persona is used to show:

- genuine disruption
- higher risk
- meaningful premium logic
- believable insured worker story

#### Bad Actor View

<table>
  <tr>
    <th>Bad Actor Home</th>
    <th>Bad Actor Insurance</th>
    <th>Bad Actor Claims</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Home%20Page%201%20Mock%20Up%20User.png" width="240" alt="Bad actor home" /></td>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Insurance%20Page%201%20Mock%20Up%20User.png" width="240" alt="Bad actor insurance" /></td>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Claims%20Page%201%20Mock%20Up%20User.png" width="240" alt="Bad actor claims" /></td>
  </tr>
  <tr>
    <td>Shows weaker disruption and lower trust signals.</td>
    <td>Shows restrained pricing under weak real-world support.</td>
    <td>Shows fraud concern and rejection-oriented claim behavior.</td>
  </tr>
</table>

This persona is used to show:

- weak disruption support
- low trigger confidence
- anomaly-based fraud concern
- rejection or guarded claim outcome

#### Premium Success View

<table>
  <tr>
    <th>Premium Success Home</th>
    <th>Premium Success Insurance</th>
    <th>Premium Success Claims</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Real%20User/Home%20Page%202%20Real%20User.png" width="240" alt="Premium success home" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Insurance%20Page%201%20Real%20User.png" width="240" alt="Premium success insurance" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Claims%20Page%202%20Real%20User.png" width="240" alt="Premium success claims" /></td>
  </tr>
  <tr>
    <td>Shows the protected worker under real disruption.</td>
    <td>Shows that protection was already active before the event.</td>
    <td>Shows approved payout, trusted record, and completed success story.</td>
  </tr>
</table>

This persona is used to show:

- policy already paid earlier
- real disruption context
- approved claim state
- payout and trust story in the claims journey

### Why These Screens Matter

The screenshots are not just UI previews. They visually demonstrate that:

- onboarding is complete and production-style
- the risk engine is visible and explainable
- the same app behaves differently across personas
- premium, claim, and payout are connected through one backend pipeline
- the demo is story-driven, not just a collection of isolated screens

## Database Design

The backend includes a structured relational schema covering:

- users
- user settings
- profiles
- verifications
- DigiLocker requests
- gig accounts
- gig income
- income summaries
- risk snapshots
- premium snapshots
- policies
- claim history
- user behavior
- model weights
- blockchain records
- bank accounts
- bank transactions

This schema supports both demo usability and a scalable production path.

## Security

Implemented protections include:

- bcrypt password hashing
- JWT-based auth
- hashed OTP storage
- rate-limiting-aware verification handling
- KYC gating through DigiLocker flow
- optional biometric login on supported devices

## Deployment

### Backend

Prepared for Render deployment with:

- PostgreSQL support
- `render.yaml`
- health endpoint
- environment-based API keys and secrets

See:

- [render.yaml](render.yaml)
- [deployment_web.md](backend/docs/deployment_web.md)

### Frontend

Flutter web is configured to use:

- `--dart-define=API_BASE_URL=...`

This allows the same codebase to support:

- local mobile testing
- LAN device testing
- hosted web deployment

## Repository Structure

### Backend

- [backend/main.py](backend/main.py)
- [backend/routes](backend/routes)
- [backend/services](backend/services)
- [backend/core](backend/core)
- [backend/models](backend/models)
- [backend/schemas](backend/schemas)

### Frontend

- [lib/main.dart](lib/main.dart)
- [lib/features](lib/features)
- [lib/services](lib/services)
- [lib/core](lib/core)

## API And Demo Docs

- [api_spec.md](backend/docs/api_spec.md)
- [actor_demo_guide.md](backend/docs/demo/actor_demo_guide.md)

## What Makes This Stand Out

This project is not just a UI demo or a static insurance calculator.

What makes it different:

- real-time environmental APIs drive core decisions
- premium and claims both reuse the same risk engine
- claim logic is explainable instead of opaque
- engine logic is explicit and auditable, not hidden in black-box prompts
- persona-driven simulation proves different outcomes on the same stack
- adaptive ML logic exists without heavyweight model infrastructure
- blockchain is integrated through a safe adapter layer instead of vendor lock-in
- the UI tells a worker-friendly story, not just a technical dashboard story

## Current Status

As of the current Phase 2 build, the system includes:

- full onboarding flow
- mandatory DigiLocker step
- gig connection module
- real-time environment and risk engine
- dynamic premium engine
- policy creation flow
- fraud-aware claim engine
- payout handling
- blockchain adapter layer
- persona simulation system
- redesigned multi-tab Flutter UX
- deployment preparation for backend and web

This creates the clearest contrast:

- one claim is blocked
- one disruption is protected

## Team

### Built by Team CampTech  
For the **Guidewire / DevTrails Hackathon**

#### Team Members

- [**Astha Bhatia**](https://github.com/asthabhatia1) – Team Leader  
- [**Jahanvi**](https://github.com/Jahanvisaini3135)  
- [**Surbhi Kaushal**](https://github.com/SurbhiKaushal)  
- [**Sanjay Kumar S**](https://github.com/Sanjay1712KSK)  
