# GigSHIELD By Team CampTech

Real-time, explainable income protection for gig workers.

This repository contains a full-stack insurtech prototype built for the DevTrails hackathon. It combines a Flutter mobile-first client with a FastAPI backend to simulate how a gig worker's live operating conditions can flow through a connected insurance pipeline:

`Environment -> Risk -> Premium -> Policy -> Claim -> Fraud -> Payout -> Blockchain Record`

## Demo Personas

The platform includes multiple demo personas so the same backend can produce clearly different insurance outcomes.

See:

- [actor_demo_guide.md](backend/docs/demo/actor_demo_guide.md)

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
