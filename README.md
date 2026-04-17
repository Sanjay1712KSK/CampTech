# GigSHIELD By Team CampTech

Real-time, explainable income protection for gig workers.

This repository contains a full-stack insurtech prototype built for the DevTrails hackathon. It combines a Flutter mobile-first client with a FastAPI backend to simulate how a gig worker's live operating conditions can flow through a connected insurance pipeline:

`Environment -> Risk -> Premium -> Policy -> Claim -> Fraud -> Payout -> Blockchain Record`

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

## 🏗 Core Platform

GigSHIELD is designed as one connected product instead of a collection of isolated features.

The core platform includes:

- secure onboarding with email OTP, phone OTP, account confirmation, and DigiLocker verification
- gig account connection with generated income history and earning baselines
- real-time environment intelligence using weather, AQI, and traffic data
- a risk engine that combines environment signals with gig and delivery context
- premium calculation driven directly by the same risk output
- weekly policy creation and activation
- a claim engine based on parametric disruption logic
- payout handling for approved claims
- blockchain logging through a mock-first adapter

What makes the base platform strong is that each layer reuses the one before it:

<<<<<<< HEAD
## Phase 3: Scale & Optimize
=======
`Gig Data -> Environment -> Risk -> Premium -> Policy -> Claim -> Payout -> Blockchain Record`
>>>>>>> cef6e3f (Readme file updated with admin screenshots and also with enhanced demo personas)

This keeps the system explainable, auditable, and reusable across worker and insurer experiences.

<<<<<<< HEAD
### Advanced Fraud Detection
=======
## 🚀 Advanced Enhancements
>>>>>>> cef6e3f (Readme file updated with admin screenshots and also with enhanced demo personas)

### 🧠 Intelligent Fraud Detection

- GPS spoof detection
- device binding with a single device per account
- session anomaly detection
- environment vs claim validation
- behavioral analysis
- continuous location tracking with user consent

### Instant Payout System

- Razorpay test integration
- automatic payout after claim approval
- transaction tracking
- linked mock bank accounts

<<<<<<< HEAD
### Zero-Touch Claim Engine
=======
### ⚡ Zero-Touch Claim System
>>>>>>> cef6e3f (Readme file updated with admin screenshots and also with enhanced demo personas)

- fully automated claim triggering
- no manual filing
- based on:
  - disruption signals
  - delivery drop
  - income loss

<<<<<<< HEAD
### Real-Time + Controlled Environment Engine
=======
### 🌐 Real-Time + Controlled Environment
>>>>>>> cef6e3f (Readme file updated with admin screenshots and also with enhanced demo personas)

- live API data
- override mode for demo scenarios
- controlled disruption simulation

### Intelligent Dashboards

Worker Dashboard:

- earnings protection
- risk visibility
- claim and payout tracking

Insurer Dashboard:

- loss ratio
- fraud analytics
- predictive insights
- recommendations

### Automated Demo System

- one-click demo from app launch
<<<<<<< HEAD
- simulates the full pipeline:
  - disruption -> risk -> claim -> fraud -> payout
- includes auto navigation, scrolling, and UI updates

## What's New Compared to Phase 2

- added intelligent fraud detection layer
- introduced instant payout system
- upgraded claim engine to fully automated parametric claims
- added real-time plus override environment simulation
- built admin insurer dashboard
- created automated demo orchestration system
- improved UI with explainable AI engine visualization
=======
- simulates the full pipeline automatically
- includes:
  - navigation
  - scrolling
  - real-time updates
>>>>>>> cef6e3f (Readme file updated with admin screenshots and also with enhanced demo personas)

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

The platform now combines multiple connected capabilities:

1. Secure onboarding for workers with email OTP, phone OTP, DigiLocker, biometric support, and device binding
2. Role-based access for workers and insurers from the app entry flow
3. Gig account connection and income history generation
4. Real-time environment, disruption, and risk intelligence
5. Dynamic premium generation, policy activation, and insurance payment flow
6. Zero-touch claim automation with fraud intelligence and instant payout simulation
7. Intelligent dashboards for both workers and insurers
8. Adaptive learning, blockchain-backed traceability, and live demo orchestration

## 🔄 How the System Works

GigSHIELD follows one connected insurance lifecycle:

`User -> Gig Data -> Environment APIs -> Risk Engine -> Premium -> Policy -> Disruption -> Claim Engine -> Fraud Check -> Payout -> Blockchain Logging`

In simple terms:

- the worker connects a gig account and the system understands their income pattern
- live environment APIs add weather, AQI, and traffic context
- the risk engine turns those signals into an explainable risk score
- the premium engine prices weekly protection from that same risk output
- after payment, the policy becomes active
- if disruption causes real earning impact, the claim engine reacts
- the fraud layer validates whether the claim matches trusted context
- if approved, the payout engine simulates instant compensation
- the system logs important records for traceability

## About the Project

Gig workers face a very different kind of financial risk compared to salaried workers. Their income can drop immediately because of rain, traffic congestion, poor air quality, or unsafe working conditions. That inspired us to build **GigSHIELD** as a live protection system that understands *why* income drops instead of reacting only after the loss.

What shaped the project most was a simple question:

> What if insurance for gig workers could understand disruption before claim time?

That idea led us to design one connected system instead of isolated features:

`Environment -> Risk -> Premium -> Policy -> Claim -> Fraud -> Payout`

### What Inspired Us

We wanted to build something grounded in real gig-worker uncertainty:

- delivery capacity changes because of weather and traffic
- safe working hours change because of heat and AQI
- weekly income is volatile even when effort stays high
- traditional claim-heavy insurance does not map well to this reality

### How We Built It

We built a full-stack prototype with:

- Flutter for the client experience
- FastAPI for backend orchestration
- SQLAlchemy for relational modeling
- SQLite for local development
- PostgreSQL-ready deployment support
- real-time environment APIs for live disruption signals
- Brevo SMTP for real email OTP delivery
- Razorpay test-mode payment and payout simulation
- modular engines for risk, premium, claims, fraud, learning, and blockchain-backed traceability
- a worker dashboard that explains the full insurance pipeline in plain language
- an insurer control panel with loss ratio, fraud analytics, and predictive insights
- a one-tap automated demo flow that can visually run the full pipeline from disruption to payout

At the center of the platform is a reasoning pipeline:

$$
\text{Environment} \rightarrow \text{Disruption} \rightarrow \text{Efficiency} \rightarrow \text{Income Loss} \rightarrow \text{Risk Score}
$$

The delivery-efficiency layer is modeled as:

$$
\text{efficiency\_score} = \text{delivery\_capacity} \times \text{working\_hours\_factor}
$$

Expected income loss is then estimated as:

$$
\text{expected\_income\_loss} = 1 - \text{efficiency\_score}
$$

The premium engine reuses the risk output directly:

$$
\text{weekly\_premium} = \text{weekly\_income} \times \text{risk\_score} \times 0.07
$$

And the fraud-aware claim layer compares predicted and actual loss:

$$
\text{predicted\_loss} = \text{risk\_score} \times \text{baseline\_income}
$$

$$
\text{fraud\_score} = \frac{\left|\text{actual\_loss} - \text{predicted\_loss}\right|}{\text{baseline\_income}}
$$

### What We Learned

This project taught us that meaningful products are not built by stacking features, but by connecting the right ideas through one consistent decision flow.

We learned:

- how to make multiple engines reuse the same logic instead of duplicating it
- how to turn raw environmental signals into understandable financial outcomes
- how to keep decisions explainable rather than opaque
- how to balance real-time APIs with mock layers for demo reliability
- how important UX clarity is in a technically complex domain

### Challenges We Faced

The hardest part was integration. Since the product combines onboarding, gig data, live environment signals, premium pricing, claim automation, fraud scoring, and payout handling, even small inconsistencies could break the full user story.

Key challenges included:

- keeping backend logic consistent across all engines
- aligning local and deployed environments
- handling OTP and email-delivery reliability
- making the demo dynamic without hardcoding outputs

We solved this by simulating only the **inputs** such as income history, user behavior, and environment, while still letting the real engines compute the outputs.

## Core Product Flow

1. User signs up
2. OTP verification is completed for contact channels
3. Email confirmation link activates the account
4. DigiLocker verification completes KYC
5. User connects a gig account
6. Gig income history is available
7. Device trust, location permission, and biometric security are established
8. Live environment APIs feed the Risk Engine
9. Premium is generated directly from Risk Engine output
10. User pays weekly premium and policy is created
11. Disruption causes income loss
12. Claim Engine validates loss and fraud risk automatically
13. Payout is issued when approved
14. Policy, claim, and payout records are written through the blockchain adapter

## Architecture

### Frontend

- Flutter
- Riverpod
- Geolocator
- Local authentication for biometric unlock on supported devices
- Role selection before authentication
- Auto-demo orchestration controller for one-tap end-to-end demos

Main UX surfaces:

- Role Selection
- Home
- Earnings
- Insurance
- Claims
- Profile
- Admin / Insurer Dashboard

### Backend

- FastAPI
- SQLAlchemy ORM
- SQLite for development
- PostgreSQL-ready production deployment
- JWT authentication
- bcrypt password hashing
- device binding and location-aware session controls
- fraud intelligence, prediction, payout, and admin analytics services

### External APIs

- Open-Meteo
- OpenWeather Air Pollution
- OpenRouteService
- Brevo SMTP
- Razorpay Test Mode

### ML / Intelligence Stack

- Heuristic + weighted decision models
- Anomaly-based fraud scoring
- Database-driven adaptive learning
- Regression-ready prediction hook
- lightweight prediction engine for next-6-hour risk, next-week claims, and expected payouts

## 🧪 How to Run Locally

### 📦 Backend (FastAPI)

1. Clone the repository.

```bash
git clone <repo_url>
cd guidewire_gig_ins/backend
```

2. Create a virtual environment.

```bash
python -m venv venv
```

Linux / macOS:

```bash
source venv/bin/activate
```

Windows:

```powershell
venv\Scripts\activate
```

3. Install dependencies.

```bash
pip install -r requirements.txt
```

4. Run the server.

```bash
uvicorn main:app --reload
```

Backend runs at:

```text
http://127.0.0.1:8000
```

### 📱 Frontend (Flutter)

1. Navigate to the project root.

```bash
cd guidewire_gig_ins
```

2. Install dependencies.

```bash
flutter pub get
```

3. Update the API base URL.

- use `http://10.0.2.2:8000` for Android emulator
- use your machine LAN IP like `http://192.168.x.x:8000` for a real device on the same Wi-Fi
- or pass it dynamically using `--dart-define`

4. Run the app.

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_LOCAL_IP:8000
```

### 📦 Build APK

```bash
flutter build apk --release
```

### 🔑 Environment Variables

Important environment variables include:

- Razorpay test keys:
  - `RAZORPAY_KEY_ID`
  - `RAZORPAY_KEY_SECRET`
- Brevo SMTP credentials:
  - `SMTP_HOST`
  - `SMTP_PORT`
  - `SMTP_USER`
  - `SMTP_PASS`
  - `SENDER_EMAIL`
- environment data providers:
  - `OPENWEATHER_API_KEY`
  - `ORS_API_KEY`
- backend configuration:
  - `DATABASE_URL`
  - `API_PUBLIC_BASE_URL`
  - `BLOCKCHAIN_MODE`

See:

- [backend/.env.example](backend/.env.example)

### Seed Demo Personas And Inputs

After the backend is running, you can seed the simulation layer:

```http
POST /simulate/input
Content-Type: application/json

{
  "enable_simulation": true,
  "regenerate_income": true,
  "days": 30
}
```

Recommended local flow:

1. Start the backend.
2. Confirm `/health` works.
3. Seed demo inputs if you want personas and dynamic scenarios.
4. Run the Flutter app with your LAN IP if testing on a real phone.
5. Test login, gig connection, risk, premium, claim, fraud, and payout flow.

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

### Zero-Touch Claim Engine

The platform also includes a zero-touch, parametric claim path.

This means:

- no manual claim filing is required for qualifying disruption-led loss
- claims can be auto-triggered from live signals
- the UI can show why the claim happened without hidden logic

Logic:

- automatically detects disruption from:
  - rain
  - traffic
  - AQI
  - delivery drop
- estimates:
  - baseline income
  - actual income
  - loss
  - loss percentage
- checks:
  - active policy
  - trigger strength
  - minimum loss threshold
  - location trust
- generates:
  - claim status
  - confidence
  - explanation
- passes the claim into fraud intelligence before payout

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

### Advanced Fraud Detection

The fraud intelligence layer now goes beyond simple anomaly scoring and includes delivery-specific fraud checks designed for gig insurance.

It can detect:

- GPS spoofing and teleport jumps
- fake weather or weak context claims using live and historical environment data
- device anomalies and multi-device access
- session anomalies and impossible travel
- user behavior deviation
- efficiency manipulation
- frequent claim abuse
- collusion-style clustered suspicious claims

This makes the platform capable of catching delivery-specific fraud patterns while still returning explainable fraud scores, signals, and decisions.

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

### 13. Prediction Engine

The backend includes a lightweight ML and prediction layer designed for fast, explainable forecasting without heavyweight infrastructure.

It predicts:

- next 6-hour risk
- next-week claims
- expected payouts
- risk trend direction

It supports:

- worker-facing predictive messaging
- insurer-facing dashboard insights
- adaptive weight tuning from recent claim outcomes

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

## Two Highlight Personas

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

- Role Selection
- Home
- Earnings
- Insurance
- Claims
- Profile
- Admin Dashboard

Key UX goals:

- explain what is happening now
- explain why the system decided that
- show how risk affects money
- make claim and payout states visible
- surface trust through transaction and blockchain cues

The demo also includes persona-specific UI explanation banners so the story changes visibly across users.

### Intelligent Dashboard

The platform now exposes intelligent dashboard experiences for both sides of the insurance system.

For Workers:

- earnings protected view
- active weekly coverage
- live environment summary
- risk explanation
- delivery impact
- auto-claim visibility
- fraud decision visibility
- payout status and transaction trail

For Insurers (Admin):

- total users
- active policies
- total claims
- total payouts
- total premiums
- loss ratio
- fraud rate and top fraud signals
- high-risk user and trigger analytics
- predictive analytics on next week's likely weather/disruption claims
- system-generated recommendations

### Insurance Payment And Payout Experience

The app now demonstrates both sides of the money flow:

- weekly premium payment and policy activation
- bank-linking for payout readiness
- instant payout system through simulated Razorpay test-mode flows

This helps show how a worker can move from paying for protection to receiving lost wages instantly when a valid disruption-led claim is approved.

### Live Demo Pipeline

The project also includes a one-click demo orchestration system.

It can visually demonstrate:

`Environment disruption -> Risk -> Claim -> Fraud -> Payout -> Admin Insights`

The automated demo can:

- start from the app entry screen
- load a demo worker
- connect gig data
- fetch environment and risk
- generate premium
- simulate disruption
- auto-trigger claims
- validate fraud
- process payout
- move into the insurer dashboard

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
- one-device-per-account binding
- session anomaly and impossible-travel checks
- continuous location validation
- location-aware claim eligibility
- fraud logs and explainable fraud signals

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
- [live_demo_runbook.md](backend/docs/live_demo_runbook.md)
- [perfect_demo_script.md](backend/docs/perfect_demo_script.md)

## 🎬 Demo Instructions

The app includes a guided demo mode that can visually run the full insurance pipeline.

### Full Demo Flow

1. Launch the app.
2. On the starting screen, tap `Start Full Demo`.
3. The system automatically runs:
   - demo worker login
   - gig connection
   - environment fetch
   - risk calculation
   - premium generation
   - policy/payment activation
   - disruption simulation
   - auto claim trigger
   - fraud validation
   - payout processing
   - insurer dashboard insights

### What the Demo Shows

- Environment disruption
- Risk increase
- Claim generation
- Fraud validation
- Instant payout simulation
- Admin analytics update

### Best Manual Demo Personas

- `good_actor` for genuine disruption story
- `bad_actor` for fraud detection story
- `premium_success` for premium-to-payout success story

### Demo Logins

Worker personas use:

```text
Password: Demo@1234
```

Admin uses:

```text
Email: admin@gigshield.com
Password: admin123
```

## What Makes This Stand Out

This project is not just a UI demo or a static insurance calculator.

What makes it different:

- real-time environmental APIs drive core decisions
- premium and claims both reuse the same risk engine
- claim logic is explainable instead of opaque
- advanced fraud detection catches delivery-specific abuse such as GPS spoofing and fake weather/context claims
- instant payout system is simulated through test-mode payment flows so the worker journey feels immediate and complete
- intelligent dashboards exist for both workers and insurers
- engine logic is explicit and auditable, not hidden in black-box prompts
- persona-driven simulation proves different outcomes on the same stack
- adaptive ML logic exists without heavyweight model infrastructure
- blockchain is integrated through a safe adapter layer instead of vendor lock-in
- the UI tells a worker-friendly story, not just a technical dashboard story

## Current Status

The current build includes:

- role selection for worker and insurer entry
- full onboarding flow
- mandatory DigiLocker step
- Brevo-based email OTP delivery
- phone OTP mock delivery for demo convenience
- device binding and secure login flow
- location permission and biometric security prompts
- gig connection module
- real-time environment and risk engine
- dynamic premium engine
- insurance payment flow with test-mode order creation
- policy creation and activation flow
- zero-touch claim engine
- fraud-aware claim engine
- advanced fraud intelligence layer
- instant payout handling
- blockchain adapter layer
- worker dashboard with explainable AI flow
- insurer admin dashboard with financial, fraud, and predictive analytics
- live demo pipeline controls and one-tap automated demo flow
- lightweight prediction engine
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
