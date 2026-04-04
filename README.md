# IncomePulse

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

IncomePulse is designed as an intelligent, modular, and explainable protection system for this exact problem space.

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

### 2. Disruption Model

Transforms environmental conditions into operational effects:

- delivery capacity
- working hours factor

This is the bridge between weather data and delivery economics.

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

### 4. Hyperlocal Engine

Compares current conditions against recent local history to determine whether today's disruption is unusually severe.

### 5. Predictive Engine

Uses forecast data to estimate near-future risk trends, especially the next 6 hours.

### 6. Trigger Engine

Activates parametric triggers such as:

- `RAIN_TRIGGER`
- `TRAFFIC_TRIGGER`
- `AQI_TRIGGER`
- `HEAT_TRIGGER`
- `COMBINED_TRIGGER`

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

### 8. Policy Engine

Creates weekly policy periods and links pricing context to the insured period.

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

### 11. Adaptive Learning Layer

Stores and updates:

- model weights
- user behavior snapshots
- claim learning history

This makes the system ML-ready while staying hackathon-practical.

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

- [actor_demo_guide.md](/s:/flutter/guidewire_gig_ins/backend/docs/demo/actor_demo_guide.md)

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

- [render.yaml](/s:/flutter/guidewire_gig_ins/render.yaml)
- [deployment_web.md](/s:/flutter/guidewire_gig_ins/backend/docs/deployment_web.md)

### Frontend

Flutter web is configured to use:

- `--dart-define=API_BASE_URL=...`

This allows the same codebase to support:

- local mobile testing
- LAN device testing
- hosted web deployment

## Repository Structure

### Backend

- [backend/main.py](/s:/flutter/guidewire_gig_ins/backend/main.py)
- [backend/routes](/s:/flutter/guidewire_gig_ins/backend/routes)
- [backend/services](/s:/flutter/guidewire_gig_ins/backend/services)
- [backend/core](/s:/flutter/guidewire_gig_ins/backend/core)
- [backend/models](/s:/flutter/guidewire_gig_ins/backend/models)
- [backend/schemas](/s:/flutter/guidewire_gig_ins/backend/schemas)

### Frontend

- [lib/main.dart](/s:/flutter/guidewire_gig_ins/lib/main.dart)
- [lib/features](/s:/flutter/guidewire_gig_ins/lib/features)
- [lib/services](/s:/flutter/guidewire_gig_ins/lib/services)
- [lib/core](/s:/flutter/guidewire_gig_ins/lib/core)

## API And Demo Docs

- [api_spec.md](/s:/flutter/guidewire_gig_ins/backend/docs/api_spec.md)
- [actor_demo_guide.md](/s:/flutter/guidewire_gig_ins/backend/docs/demo/actor_demo_guide.md)

## What Makes This Stand Out

This project is not just a UI demo or a static insurance calculator.

What makes it different:

- real-time environmental APIs drive core decisions
- premium and claims both reuse the same risk engine
- claim logic is explainable instead of opaque
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

## Demo Strategy

For short demo videos and judging:

- use `bad_actor` to show fraud prevention
- use `premium_success` to show real insured value and payout

This creates the clearest contrast:

- one claim is blocked
- one disruption is protected

## Team

Built by Team CampTech for the Guidewire / DevTrails hackathon.
