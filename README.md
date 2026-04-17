# GigSHIELD By Team CampTech

Real-time, explainable income protection for gig workers.

This repository contains a full-stack insurtech prototype built for the DevTrails hackathon. It combines a Flutter mobile-first client with a FastAPI backend to show how a gig worker's live operating conditions can flow through a connected insurance pipeline:

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

## Core Platform

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

`Gig Data -> Environment -> Risk -> Premium -> Policy -> Claim -> Payout -> Blockchain Record`

This keeps the system explainable, auditable, and reusable across worker and insurer experiences.

## Advanced Enhancements

### Intelligent Fraud Detection

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

### Zero-Touch Claim System

- fully automated claim triggering
- no manual filing for qualifying disruption-led loss
- based on:
  - disruption signals
  - delivery drop
  - income loss

### Real-Time Plus Controlled Environment

- live API data
- override mode for demo scenarios
- controlled disruption simulation

### Intelligent Dashboards

Worker dashboard:

- earnings protection
- risk visibility
- claim and payout tracking

Insurer dashboard:

- loss ratio
- fraud analytics
- predictive insights
- recommendations

### Automated Demo System

- one-click demo from app launch
- simulates the full pipeline automatically
- includes:
  - navigation
  - scrolling
  - real-time updates

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
- bank-linking details for demo payout readiness

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

## How the System Works

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

## About The Project

Gig workers face a very different kind of financial risk compared to salaried workers. Their income can drop immediately because of rain, traffic congestion, poor air quality, or unsafe working conditions. That inspired us to build GigSHIELD as a live protection system that understands why income drops instead of reacting only after the loss.

What shaped the project most was a simple question:

> What if insurance for gig workers could understand disruption before claim time?

That idea led us to design one connected system instead of isolated features:

`Environment -> Risk -> Premium -> Policy -> Claim -> Fraud -> Payout`

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

The core engine models used in the platform are:

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

The fraud-aware claim layer compares predicted and actual loss:

$$
\text{predicted\_loss} = \text{risk\_score} \times \text{baseline\_income}
$$

$$
\text{fraud\_score} = \frac{\left|\text{actual\_loss} - \text{predicted\_loss}\right|}{\text{baseline\_income}}
$$

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
- role selection before authentication
- auto-demo orchestration controller for one-tap end-to-end demos

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

- heuristic and weighted decision models
- anomaly-based fraud scoring
- database-driven adaptive learning
- regression-ready prediction hook
- lightweight prediction engine for next-6-hour risk, next-week claims, and expected payouts

## How To Run Locally

### Backend (FastAPI)

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

### Frontend (Flutter)

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

### Build APK

```bash
flutter build apk --release
```

### Environment Variables

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

## Demo Personas

The platform includes multiple demo personas so the same backend can produce clearly different insurance outcomes.

See:

- [actor_demo_guide.md](backend/docs/demo/actor_demo_guide.md)

### Arjun - The Honest Worker (Primary Flow)

- consistent delivery partner
- has active policy
- location tracking enabled

Scenario:

- heavy rain occurs
- deliveries drop significantly
- system auto-detects loss

Outcome:

- claim auto-triggered
- fraud check passed
- instant payout credited

### Rahul - Fraud Attempt

- attempts to manipulate the system
- fake delivery drop
- GPS inconsistency

Outcome:

- fraud signals detected such as GPS mismatch and behavioral anomaly
- claim rejected
- no payout issued

### Meena - Edge Case User

- experiences mild disruption
- moderate income drop

Outcome:

- claim triggered with medium confidence
- partial payout issued

### Insurer (Admin Persona)

- monitors system performance

Capabilities:

- view loss ratio
- analyze fraud trends
- predict claim surge
- get system recommendations

### Karthik - Restricted User (No Permissions)

- denies location access

Outcome:

- limited coverage
- claim restricted or not triggered

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

For workers:

- earnings protected view
- active weekly coverage
- live environment summary
- risk explanation
- delivery impact
- auto-claim visibility
- fraud decision visibility
- payout status and transaction trail

For insurers:

- total users
- active policies
- total claims
- total payouts
- total premiums
- loss ratio
- fraud rate and top fraud signals
- high-risk user and trigger analytics
- predictive analytics on next week's likely weather and disruption claims
- system-generated recommendations

### Insurance Payment And Payout Experience

The app demonstrates both sides of the money flow:

- weekly premium payment and policy activation
- bank-linking for payout readiness
- instant payout system through simulated Razorpay test-mode flows

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
- most screenshot files are resized or compressed exports in an approximate range of `378-386 px` width and `845-855 px` height
- small dimension differences across files are due to cropping and export variation, not UI inconsistency

### Entrance Screen

Description:
User selects role as Worker or Insurer, or starts the automated full demo from the first screen.

<table>
  <tr>
    <th>Entrance Screen</th>
  </tr>
  <tr>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/App%20Entrance%20Page.png" width="260" alt="App entrance screen" /></td>
  </tr>
  <tr>
    <td>Role selection and one-click demo launch surface for the entire platform.</td>
  </tr>
</table>

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

### Insurer Control Center (Admin Dashboard)

Description:
A powerful dashboard for insurers to monitor system health, fraud patterns, and predictive insights.

#### Admin Access

<table>
  <tr>
    <th>Admin Login</th>
    <th>System Health</th>
    <th>System Health 2</th>
  </tr>
  <tr>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Admin%20Demo%20Login%20Page.png" width="240" alt="Admin demo login page" /></td>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Insurer%20Control%20Center%20-%20System%20Health.png" width="240" alt="Insurer control center system health" /></td>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Insurer%20Control%20Center%20-%20System%20Health%202.png" width="240" alt="Insurer control center system health 2" /></td>
  </tr>
  <tr>
    <td>Secure entry point for the insurer control center.</td>
    <td>Provides a high-level summary of system performance.</td>
    <td>Provides an additional high-level summary of system performance.</td>
  </tr>
</table>

#### Fraud And Risk Analytics

<table>
  <tr>
    <th>Fraud Intelligence</th>
    <th>Fraud Hotspots + Risk and Claim Trends</th>
    <th>Risk Analytics and Financial Health</th>
  </tr>
  <tr>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Insurer%20Control%20Center%20-%20Fraud%20Intelligence.png" width="240" alt="Insurer control center fraud intelligence" /></td>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Insurer%20Control%20Center%20-%20Fraud%20Hotspots%20%2B%20Risk%20and%20claim%20trends.png" width="240" alt="Insurer control center fraud hotspots risk and claim trends" /></td>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Insurer%20Control%20Center%20-%20Risk%20Analytics%20and%20Financial%20Health.png" width="240" alt="Insurer control center risk analytics and financial health" /></td>
  </tr>
  <tr>
    <td>Displays fraud detection metrics and flagged claims.</td>
    <td>Shows city-wise fraud activity alongside risk and claim trend monitoring.</td>
    <td>Illustrates risk analytics together with overall financial health.</td>
  </tr>
</table>

#### Predictions And Recommendations

<table>
  <tr>
    <th>Predictions</th>
    <th>Smart Insights</th>
    <th>AI Recommendations</th>
  </tr>
  <tr>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Insurer%20Control%20Center%20-%20Predictions.png" width="240" alt="Insurer control center predictions" /></td>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Insurer%20Control%20Center%20-%20Smart%20Insights.png" width="240" alt="Insurer control center smart insights" /></td>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Insurer%20Control%20Center%20-%20AI%20recommendations.png" width="240" alt="Insurer control center ai recommendations" /></td>
  </tr>
  <tr>
    <td>Shows predictive analytics for future claims and payouts.</td>
    <td>Summarizes smart insights from platform trends and system intelligence.</td>
    <td>Presents system-generated recommendations for insurer action.</td>
  </tr>
</table>

### Why These Screens Matter

- onboarding is complete and production-style
- the risk engine is visible and explainable
- the same app behaves differently across personas
- premium, claim, and payout are connected through one backend pipeline
- the demo is story-driven, not just a collection of isolated screens

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

## Demo Instructions

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

### What The Demo Shows

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
- advanced fraud detection catches delivery-specific abuse such as GPS spoofing and fake weather or context claims
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

Built by Team CampTech for the Guidewire / DevTrails Hackathon.
