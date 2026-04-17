# 🚀 GigShield — Intelligent Insurance for Gig Workers

Real-time, AI-powered insurance for gig workers that automatically detects income disruption, validates claims, prevents fraud, and issues instant payouts.

GigShield is a full-stack insurtech platform built to protect delivery and gig-economy workers from sudden earning shocks caused by weather, traffic, air quality, and other real-world disruptions. It combines live environment intelligence, explainable risk scoring, weekly policy pricing, zero-touch claims, fraud detection, payout orchestration, and insurer analytics inside one connected product experience.

---

## 🎯 What GigShield Solves

Gig workers do not operate in stable working conditions.

- rain reduces delivery throughput
- traffic increases delays and missed orders
- AQI and heat can reduce safe working hours
- weekly income can collapse even when workers do everything right

Traditional insurance is usually a weak fit because it is:

- slow
- reactive
- paperwork-heavy
- not hyperlocal
- not explainable to workers
- not aligned with weekly gig cash flow

GigShield is designed as an always-on, explainable, demo-ready insurance platform that responds to the same signals that affect worker income in the real world.

---

## 🎥 Demo & Access

- [🎬 Demo Video](./Demo/Phase%202%20.mp4)
- [📦 GitHub Releases](https://github.com/Sanjay1712KSK/GuideWire/releases)
- [📱 APK Download Page](https://github.com/Sanjay1712KSK/GuideWire/releases)
- [📄 Pitch Deck](./GigShield%20Final%20Pitch%20Deck%20PPT.pdf)

---

## 🧩 Product At A Glance

GigShield connects the full insurance lifecycle into one product pipeline:

`User -> Gig Data -> Environment -> Risk -> Premium -> Policy -> Disruption -> Claim -> Fraud -> Payout -> Blockchain`

At a high level:

- the worker signs in and completes verification
- the platform understands the worker's gig income baseline
- live weather, AQI, and traffic data are pulled in
- risk is calculated using real operating conditions
- weekly premium is generated from the same risk output
- policy is activated after payment
- disruption and income loss are monitored
- claims are triggered and evaluated automatically
- fraud checks run before payout
- payout is recorded and audit logs are written through the blockchain adapter

---

## 🏗 Core Platform

GigShield is built as a single insurance system rather than a collection of disconnected features.

### 👤 User Onboarding

- worker and insurer role selection from the entrance screen
- signup flow with complete registration screens
- email and phone OTP verification
- email account confirmation
- DigiLocker-style identity verification
- password recovery flow
- biometric-ready secure login support
- device-aware trust controls

### 🔗 Gig Account Integration

- simulated gig-platform account connection
- generated earnings history and trend modeling
- income baseline creation for disruption comparison
- persona-ready seeded demo workers

### 🌦 Environment Intelligence

- live weather signals via `Open-Meteo`
- live AQI context via `OpenWeather Air Pollution API`
- traffic context via `OpenRouteService`
- simulation override support for reliable demos
- controlled disruption triggers for storytelling

### 📉 Risk Engine

- combines hyperlocal environment signals with worker context
- estimates disruption intensity and expected income loss
- produces explainable risk outputs
- powers downstream premium and claim logic

### 💵 Premium Generation

- weekly premium calculation driven by risk output
- pricing changes with real conditions
- safer conditions can lead to lower premium
- riskier conditions justify stronger protection pricing

### 🛡 Policy Creation

- policy activation after premium payment
- insurance state tracking
- coverage visibility inside the app
- policy history support through backend records

### ⚡ Parametric Claim Engine

- disruption-aware claim evaluation
- zero-touch automation for qualifying cases
- claim path based on disruption plus income loss
- explainable eligibility and guarded outcomes

### 💸 Payout System

- payout readiness through linked mock bank accounts
- Razorpay test integration for payment and payout flow
- automatic payout for valid claims
- transaction tracking and status visibility

### ⛓ Blockchain Adapter

- policy, claim, and payout events logged through a mock-first adapter
- trust and audit trail support
- safe demonstration of immutable-record thinking without external blockchain dependency during demos

---

## 🚀 Advanced Enhancements

Phase 3 is the strongest evolution of the platform. It shifts GigShield from a solid prototype into a complete, presentation-ready, productized insurance experience.

### 🧠 Intelligent Fraud Detection

- GPS spoof detection
- single-device binding
- session anomaly detection
- behavior pattern analysis
- disruption-versus-claim mismatch checks
- weather mismatch validation
- location-aware claim trust controls

### 💰 Instant Payout System

- Razorpay test-mode integration
- automatic payout flow after approval
- linked mock bank accounts
- transaction and payout trail visibility
- clearer trust and completion story for judges

### ⚡ Zero-Touch Claim Engine

- fully automated claim triggering
- no manual claim filing needed for valid disruption-led loss
- connects disruption, worker baseline, and payout decisioning

### 🌐 Real-Time + Controlled Demo Environment

- real APIs for live data
- simulation override for consistent presentations
- controlled trigger buttons for rain and fraud stories
- repeatable demos without hardcoding outcomes

### 📊 Intelligent Dashboards

`Worker dashboard`

- current risk
- earnings changes
- protection visibility
- claim state
- payout state
- explainable AI flow

`Insurer dashboard`

- system health
- fraud analytics
- hotspots and trends
- loss ratio
- financial health
- predictions
- smart insights
- AI recommendations

### 🎬 Automated Demo System

- one-click demo entry from app start
- automated navigation flow
- full-pipeline story execution
- controlled screen movement and scrolling
- fast presentation mode for judges

---

## 🏛 Architecture

### 📱 Frontend

- Flutter
- Riverpod
- mobile-first multi-tab UX
- persona-aware flows
- role-based entry and dashboard experiences
- biometric support via local authentication

Main app surfaces:

- role selection
- login and signup
- onboarding and verification
- worker home
- earnings
- insurance
- claims
- profile
- admin / insurer control center

### ⚙ Backend

- FastAPI
- SQLAlchemy
- SQLite for local development
- PostgreSQL-ready deployment path
- JWT authentication
- bcrypt password hashing
- service-oriented architecture
- dedicated engines for risk, premium, claim, fraud, prediction, payout, and admin analytics

### 🔌 External Integrations

- Open-Meteo
- OpenWeather Air Pollution API
- OpenRouteService
- Brevo SMTP
- Razorpay test mode

### 🤖 Intelligence Layer

- rule-based and weighted scoring
- anomaly-driven fraud logic
- predictive analytics hooks
- explainable output generation
- simulation-assisted but engine-driven product behavior

---

## 🔄 How The System Works

### 1. Worker Identity And Access

- user selects worker or insurer role
- user signs up or logs in
- OTP and confirmation steps establish trusted identity
- DigiLocker-style verification completes onboarding

### 2. Gig Baseline Creation

- worker connects a gig account
- earnings history is generated or seeded
- system learns the worker's operating baseline

### 3. Live Environment Capture

- weather, AQI, and traffic are fetched
- optional simulation inputs modify conditions for demo control
- worker context is refreshed with environment intelligence

### 4. Risk And Pricing

- risk engine calculates disruption impact
- expected income loss is estimated
- premium engine prices weekly protection

### 5. Policy Activation

- worker pays premium
- policy becomes active
- coverage status is shown inside the app

### 6. Disruption And Claims

- disruption affects worker operating conditions
- claim engine evaluates whether a valid income-loss event occurred
- system can auto-trigger a claim for qualifying cases

### 7. Fraud Checks

- location and session patterns are checked
- spoofing and mismatch signals are evaluated
- suspicious claims can be blocked or restricted

### 8. Payout And Trust

- valid claims flow into payout processing
- payout status is tracked
- policy, claim, and payout records are logged through the blockchain adapter

---

## 📐 Explainable Product Logic

GigShield is designed so the core engines reuse one another instead of producing isolated outputs.

### Environment To Risk

The platform models a disruption pipeline conceptually as:

`Environment -> Disruption -> Efficiency -> Income Loss -> Risk`

### Efficiency Layer

The delivery efficiency idea used in the platform is:

`efficiency_score = delivery_capacity x working_hours_factor`

### Expected Income Loss

The expected income loss idea is:

`expected_income_loss = 1 - efficiency_score`

### Premium Logic

Weekly premium is derived from risk and weekly income context:

`weekly_premium = weekly_income x risk_score x 0.07`

### Fraud Awareness

The fraud layer compares predicted loss against actual story consistency:

`predicted_loss = risk_score x baseline_income`

`fraud_score = |actual_loss - predicted_loss| / baseline_income`

The key product principle is that simulation feeds inputs, but the engines still generate risk, premium, claim, and fraud outcomes.

---

## 🌐 What Is Live And What Is Simulated

### ✅ Live / Real-Time

- weather signals
- AQI signals
- traffic context
- risk scoring
- premium generation
- trigger evaluation
- claim reasoning
- admin analytics surfaces

### 🧪 Simulated / Mocked For Demo Practicality

- some OTP convenience flows
- DigiLocker demo path
- gig-platform data connection
- seeded personas and baseline data
- mock-first blockchain target
- mock bank-linking readiness

Important note:

- simulation injects inputs and demo conditions
- it does not hardcode the final engine outputs

---

## 👤 Demo Personas

GigShield includes multiple personas so judges can see honest, fraudulent, ambiguous, low-risk, and insurer perspectives on the same stack.

### 🟢 Arjun — Honest Worker

- represents a genuine worker under real disruption
- best for showing valid claim and payout logic
- consistent work pattern
- strong policyholder story

### 🔴 Rahul — Fraud Attempt

- represents manipulation or weakly supported claim behavior
- best for showing fraud detection, mismatch checks, and payout blocking
- useful for spoofing and anomaly narrative

### 🟡 Meena — Edge Case

- represents ambiguous or medium-confidence cases
- best for showing explainable review behavior
- helps demonstrate fairness beyond approve-or-reject extremes

### 🏢 Insurer — Admin Persona

- best for showing operational monitoring
- includes fraud intelligence, system health, predictions, and recommendations

### 🔵 Karthik — Restricted / Low-Risk User

- useful for showing fair pricing under calmer conditions
- helps demonstrate limited claimability when disruption support is weak

### ⭐ Premium Success Persona

- shows the strongest full premium-to-payout story
- best for fast presentations where the audience needs to see end-to-end value quickly

---

## 🖼 Complete Screenshot Library

The README below includes the screenshot collections from:

- `Demo/Screenshots`
- `Demo/Phase 3 Demo Screenshots`

The sections are ordered to match product flow and persona storytelling.

---

## 🚪 Phase 3 Entry & Admin Access

### App Entrance

<table>
  <tr>
    <th>Entrance Screen</th>
  </tr>
  <tr>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/App%20Entrance%20Page.png" width="280" alt="GigShield app entrance page" /></td>
  </tr>
  <tr>
    <td>Role selection and one-click demo launch surface for the complete product journey.</td>
  </tr>
</table>

### Admin Entry

<table>
  <tr>
    <th>Admin Demo Login</th>
  </tr>
  <tr>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Admin%20Demo%20Login%20Page.png" width="280" alt="GigShield admin demo login page" /></td>
  </tr>
  <tr>
    <td>Secure insurer access point into the Phase 3 control center experience.</td>
  </tr>
</table>

---

## 🛡 Insurer Control Center

### System Health

<table>
  <tr>
    <th>System Health</th>
    <th>System Health 2</th>
  </tr>
  <tr>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Insurer%20Control%20Center%20-%20System%20Health.png" width="240" alt="Insurer control center system health" /></td>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Insurer%20Control%20Center%20-%20System%20Health%202.png" width="240" alt="Insurer control center system health second screen" /></td>
  </tr>
  <tr>
    <td>High-level operational snapshot of platform activity, system load, and health indicators.</td>
    <td>Expanded health perspective that helps judges see the control-center depth beyond a single summary view.</td>
  </tr>
</table>

### Fraud, Risk, And Financial Monitoring

<table>
  <tr>
    <th>Fraud Intelligence</th>
    <th>Fraud Hotspots + Risk And Claim Trends</th>
    <th>Risk Analytics And Financial Health</th>
  </tr>
  <tr>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Insurer%20Control%20Center%20-%20Fraud%20Intelligence.png" width="220" alt="Insurer control center fraud intelligence" /></td>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Insurer%20Control%20Center%20-%20Fraud%20Hotspots%20%2B%20Risk%20and%20claim%20trends.png" width="220" alt="Insurer control center fraud hotspots risk and claim trends" /></td>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Insurer%20Control%20Center%20-%20Risk%20Analytics%20and%20Financial%20Health.png" width="220" alt="Insurer control center risk analytics and financial health" /></td>
  </tr>
  <tr>
    <td>Fraud metrics, flagged patterns, and insurer-facing signal visibility.</td>
    <td>Geographic and trend-oriented view of suspicious activity, rising claim pressure, and changing risk patterns.</td>
    <td>Combined operational and financial perspective showing risk performance and insurer sustainability signals.</td>
  </tr>
</table>

### Predictions, Insights, And Recommendations

<table>
  <tr>
    <th>Predictions</th>
    <th>Smart Insights</th>
    <th>AI Recommendations</th>
  </tr>
  <tr>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Insurer%20Control%20Center%20-%20Predictions.png" width="220" alt="Insurer control center predictions" /></td>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Insurer%20Control%20Center%20-%20Smart%20Insights.png" width="220" alt="Insurer control center smart insights" /></td>
    <td><img src="Demo/Phase%203%20Demo%20Screenshots/Insurer%20Control%20Center%20-%20AI%20recommendations.png" width="220" alt="Insurer control center AI recommendations" /></td>
  </tr>
  <tr>
    <td>Forward-looking estimates for claims, payouts, and disruption-related pressure.</td>
    <td>Summarized intelligence that helps insurers interpret what the system is seeing right now.</td>
    <td>Action-oriented recommendations that translate analytics into insurer decisions.</td>
  </tr>
</table>

---

## 👤 Real User Journey Screens

### Authentication & Verification

<table>
  <tr>
    <th>Login</th>
    <th>Forgot Password</th>
    <th>Sign Up</th>
    <th>Sign Up Filled</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Real%20User/Login%20In%20Page.png" width="210" alt="Real user login page" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Forgot%20Password%20Page.png" width="210" alt="Real user forgot password page" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Sign%20Up%20Page.png" width="210" alt="Real user sign up page" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Sign%20Up%20Page%20With%20Credentials%20Filled.png" width="210" alt="Real user sign up page filled" /></td>
  </tr>
  <tr>
    <td>Main login screen for returning users.</td>
    <td>Password recovery entry point for account support and resilience.</td>
    <td>Fresh worker onboarding form.</td>
    <td>Shows the completed registration form state before submission.</td>
  </tr>
</table>

<table>
  <tr>
    <th>Verify Contact Channels</th>
    <th>Email Confirmation</th>
    <th>Mail OTP</th>
    <th>DigiLocker Verification</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Real%20User/Verify%20Contact%20Channels.png" width="210" alt="Real user verify contact channels" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Email%20Confirmation%20Page.png" width="210" alt="Real user email confirmation page" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Mail%20OTP%20Screenshot.png" width="210" alt="Real user mail OTP screenshot" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Digilocker%20Verification%20Mockup.png" width="210" alt="Real user DigiLocker verification mockup" /></td>
  </tr>
  <tr>
    <td>Dual-channel contact verification for stronger onboarding trust.</td>
    <td>Account activation state after email confirmation.</td>
    <td>Shows OTP delivery and verification support within the onboarding experience.</td>
    <td>Identity verification stage before the worker enters the core insurance flow.</td>
  </tr>
</table>

### Gig Connection

<table>
  <tr>
    <th>Gig Account Connection</th>
    <th>Gig Account Connection 2</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Real%20User/Gig%20Account%20Mockup%20Connection.png" width="240" alt="Real user gig account connection screen" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Gig%20Account%20Mockup%20Connection%202.png" width="240" alt="Real user gig account connection continuation screen" /></td>
  </tr>
  <tr>
    <td>Initial gig-platform connection flow used to establish worker earnings context.</td>
    <td>Continuation of account linkage and platform-specific setup for downstream risk and policy logic.</td>
  </tr>
</table>

### Real User Home Flow

<table>
  <tr>
    <th>Home 1</th>
    <th>Home 2</th>
    <th>Home 3</th>
    <th>Home 4</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Real%20User/Home%20Page%201%20Real%20User.png" width="190" alt="Real user home page 1" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Home%20Page%202%20Real%20User.png" width="190" alt="Real user home page 2" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Home%20Page%203%20Real%20User.png" width="190" alt="Real user home page 3" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Home%20Page%204%20Real%20User.png" width="190" alt="Real user home page 4" /></td>
  </tr>
  <tr>
    <td>Primary worker dashboard with live disruption and protection context.</td>
    <td>Expanded risk and payout-relevant state after more interaction.</td>
    <td>Additional explainable dashboard detail within the home flow.</td>
    <td>Deeper home-state visibility for worker context and system status.</td>
  </tr>
</table>

### Real User Earnings Flow

<table>
  <tr>
    <th>Earnings 1</th>
    <th>Earnings 2</th>
    <th>Earnings 3</th>
    <th>Earnings 4</th>
    <th>Earnings 5</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Real%20User/Earnings%201%20Real%20User.png" width="170" alt="Real user earnings page 1" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Earnings%202%20Real%20User.png" width="170" alt="Real user earnings page 2" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Earnings%203%20Real%20User.png" width="170" alt="Real user earnings page 3" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Earnings%204%20Real%20User.png" width="170" alt="Real user earnings page 4" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Earnings%205%20Real%20User.png" width="170" alt="Real user earnings page 5" /></td>
  </tr>
  <tr>
    <td>Entry view into earnings intelligence and worker income history.</td>
    <td>Additional earnings analytics and trend depth.</td>
    <td>Pattern-focused earnings behavior screen.</td>
    <td>More detailed performance and loss visibility.</td>
    <td>Expanded history and earning-pattern storytelling for demo narration.</td>
  </tr>
</table>

### Real User Insurance & Claims

<table>
  <tr>
    <th>Insurance</th>
    <th>Claims 1</th>
    <th>Claims 2</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Real%20User/Insurance%20Page%201%20Real%20User.png" width="220" alt="Real user insurance page" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Claims%20Page%201%20Real%20User.png" width="220" alt="Real user claims page 1" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Claims%20Page%202%20Real%20User.png" width="220" alt="Real user claims page 2" /></td>
  </tr>
  <tr>
    <td>Premium, coverage, and protection explanation surface for the worker.</td>
    <td>Claim-state screen showing automation and decision visibility.</td>
    <td>Payout-oriented outcome screen showing claim completion state.</td>
  </tr>
</table>

### Real User Profile

<table>
  <tr>
    <th>Profile 1</th>
    <th>Profile 2</th>
    <th>Profile 3</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Real%20User/Profile%20Page%201%20Real%20User.png" width="220" alt="Real user profile page 1" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Profile%20Page%202%20Real%20User.png" width="220" alt="Real user profile page 2" /></td>
    <td><img src="Demo/Screenshots/Real%20User/Profile%20Page%203%20Real%20User.png" width="220" alt="Real user profile page 3" /></td>
  </tr>
  <tr>
    <td>Worker profile overview and account information.</td>
    <td>Expanded profile details and preference visibility.</td>
    <td>Additional profile and account-state controls.</td>
  </tr>
</table>

---

## 🟢 Honest Persona Screens — Good Mock Up User

This persona is the trusted-worker story and best represents a valid disruption-led payout path.

### Good Persona Sign-In Sequence

<table>
  <tr>
    <th>Sign In 1</th>
    <th>Sign In 2</th>
    <th>Sign In 3</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Sign%20In%20Page%201%20Mock%20Up%20User.png" width="210" alt="Good persona sign in page 1" /></td>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Sign%20In%20Page%202%20Mock%20Up%20User.png" width="210" alt="Good persona sign in page 2" /></td>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Sign%20In%20Page%203%20Mock%20Up%20User.png" width="210" alt="Good persona sign in page 3" /></td>
  </tr>
  <tr>
    <td>Beginning of the good-user authentication journey.</td>
    <td>Mid-flow trusted login progression for the good actor.</td>
    <td>Further sign-in progress showing the complete entry experience.</td>
  </tr>
</table>

<table>
  <tr>
    <th>Sign In 4</th>
    <th>Sign In 5</th>
    <th>Sign In 6</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Sign%20In%20Page%204%20Mock%20Up%20User.png" width="210" alt="Good persona sign in page 4" /></td>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Sign%20In%20Page%205%20Mock%20Up%20User.png" width="210" alt="Good persona sign in page 5" /></td>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Sign%20In%20Page%206%20Mock%20Up%20User.png" width="210" alt="Good persona sign in page 6" /></td>
  </tr>
  <tr>
    <td>Late-stage trusted entry state in the good-user story.</td>
    <td>Near-complete authentication flow for the honest persona.</td>
    <td>Final good-user sign-in step before product interaction.</td>
  </tr>
</table>

### Good Persona Core Tabs

<table>
  <tr>
    <th>Home</th>
    <th>Earnings 1</th>
    <th>Earnings 2</th>
    <th>Earnings 3</th>
    <th>Earnings 4</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Home%20Page%201%20Mock%20Up%20User.png" width="170" alt="Good persona home page" /></td>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Earnings%20Page%201%20Mock%20Up%20User.png" width="170" alt="Good persona earnings page 1" /></td>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Earnings%20Page%202%20Mock%20Up%20User.png" width="170" alt="Good persona earnings page 2" /></td>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Earnings%20Page%203%20Mock%20Up%20User.png" width="170" alt="Good persona earnings page 3" /></td>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Earnings%20Page%204%20Mock%20Up%20User.png" width="170" alt="Good persona earnings page 4" /></td>
  </tr>
  <tr>
    <td>Trusted-worker home dashboard showing the strongest honest disruption narrative.</td>
    <td>Beginning of earnings evidence for genuine loss context.</td>
    <td>More earnings support for the good actor story.</td>
    <td>Extended performance trend for the honest worker.</td>
    <td>Additional proof of earnings behavior under disruption conditions.</td>
  </tr>
</table>

<table>
  <tr>
    <th>Insurance 1</th>
    <th>Insurance 2</th>
    <th>Claims</th>
    <th>Profile 1</th>
    <th>Profile 2</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Insurance%20Page%201%20Mock%20Up%20User.png" width="170" alt="Good persona insurance page 1" /></td>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Insurance%20Page%202%20Mock%20Up%20User.png" width="170" alt="Good persona insurance page 2" /></td>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Claims%20Page%201%20Mock%20Up%20User.png" width="170" alt="Good persona claims page" /></td>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Profile%20Page%201%20Mock%20Up%20User.png" width="170" alt="Good persona profile page 1" /></td>
    <td><img src="Demo/Screenshots/Good%20Mock%20Up%20User/Profile%20Page%202%20Mock%20Up%20User.png" width="170" alt="Good persona profile page 2" /></td>
  </tr>
  <tr>
    <td>Pricing and protection context for the good actor under meaningful risk.</td>
    <td>Deeper coverage and policy view for the honest-user story.</td>
    <td>Claim surface that best supports the valid-claim explanation.</td>
    <td>Profile and account state for the good persona.</td>
    <td>Additional profile details for the trusted-worker scenario.</td>
  </tr>
</table>

---

## 🔴 Fraud Persona Screens — Bad Mock Up User

This persona is designed to show how the platform resists manipulation and prevents invalid payouts.

### Bad Persona Entry & Verification

<table>
  <tr>
    <th>Sign In</th>
    <th>OTP Verification</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Sign%20In%20Page%20Mock%20Up%20User.png" width="240" alt="Bad persona sign in page" /></td>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/OTP%20Verification%20Page%20Mock%20Up%20User.png" width="240" alt="Bad persona OTP verification page" /></td>
  </tr>
  <tr>
    <td>Fraud-attempt persona login entry.</td>
    <td>Verification step before the suspicious-user journey proceeds.</td>
  </tr>
</table>

### Bad Persona Home & Earnings Flow

<table>
  <tr>
    <th>Home 1</th>
    <th>Home 2</th>
    <th>Home 3</th>
    <th>Home 4</th>
    <th>Home 5</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Home%20Page%201%20Mock%20Up%20User.png" width="170" alt="Bad persona home page 1" /></td>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Home%20Page%202%20Mock%20Up%20User.png" width="170" alt="Bad persona home page 2" /></td>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Home%20Page%203%20Mock%20Up%20User.png" width="170" alt="Bad persona home page 3" /></td>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Home%20Page%204%20Mock%20Up%20User.png" width="170" alt="Bad persona home page 4" /></td>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Home%20Page%205%20Mock%20Up%20User.png" width="170" alt="Bad persona home page 5" /></td>
  </tr>
  <tr>
    <td>Initial suspicious-user home state.</td>
    <td>Further context showing weaker support for a valid claim story.</td>
    <td>Another home-state view exposing mismatch-driven narrative.</td>
    <td>Additional fraud-story dashboard context.</td>
    <td>Deepest home-state screen for the system-gamer persona.</td>
  </tr>
</table>

<table>
  <tr>
    <th>Earnings 1</th>
    <th>Earnings 2</th>
    <th>Earnings 3</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Earnings%20Page%201%20Mock%20Up%20User.png" width="220" alt="Bad persona earnings page 1" /></td>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Earnings%20Page%202%20Mock%20Up%20User.png" width="220" alt="Bad persona earnings page 2" /></td>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Earnings%20Page%203%20Mock%20Up%20User.png" width="220" alt="Bad persona earnings page 3" /></td>
  </tr>
  <tr>
    <td>Beginning of the weaker-justification earnings story.</td>
    <td>Additional earnings context that supports fraud mismatch logic.</td>
    <td>Extended performance view for rejection-oriented demonstrations.</td>
  </tr>
</table>

### Bad Persona Insurance, Claims, And Profile

<table>
  <tr>
    <th>Insurance 1</th>
    <th>Insurance 2</th>
    <th>Claims 1</th>
    <th>Claims 2</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Insurance%20Page%201%20Mock%20Up%20User.png" width="190" alt="Bad persona insurance page 1" /></td>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Insurance%20Page%202%20Mock%20Up%20User.png" width="190" alt="Bad persona insurance page 2" /></td>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Claims%20Page%201%20Mock%20Up%20User.png" width="190" alt="Bad persona claims page 1" /></td>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Claims%20Page%202%20Mock%20Up%20User.png" width="190" alt="Bad persona claims page 2" /></td>
  </tr>
  <tr>
    <td>Insurance surface for a weaker and more suspicious scenario.</td>
    <td>Additional pricing and protection context under weak evidence.</td>
    <td>Claim screen used to explain fraud caution.</td>
    <td>Extended claim-state outcome for blocked or suspicious behavior.</td>
  </tr>
</table>

<table>
  <tr>
    <th>Profile 1</th>
    <th>Profile 2</th>
    <th>Profile 3</th>
  </tr>
  <tr>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Profile%20Page%201%20Mock%20Up%20User.png" width="220" alt="Bad persona profile page 1" /></td>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Profile%20Page%202%20Mock%20Up%20User.png" width="220" alt="Bad persona profile page 2" /></td>
    <td><img src="Demo/Screenshots/Bad%20Mock%20Up%20User/Profile%20Page%203%20Mock%20Up%20User.png" width="220" alt="Bad persona profile page 3" /></td>
  </tr>
  <tr>
    <td>Profile state for the fraud-attempt persona.</td>
    <td>More account details within the suspicious-user story.</td>
    <td>Additional profile controls and context for the bad actor.</td>
  </tr>
</table>

---

## 🎬 Phase Walkthrough Summary

### Phase 1 — Access And Trust Establishment

- role selection
- signup and login
- OTP flows
- email confirmation
- DigiLocker verification
- gig account connection

### Phase 2 — Core Insurance Engine

- live environment capture
- risk scoring
- premium generation
- policy creation
- claims interface
- worker dashboards

### Phase 3 — Productized Intelligence Layer

- fraud intelligence
- instant payouts
- zero-touch claims
- full admin control center
- predictions and recommendations
- automated demo orchestration

---

## 📦 Releases

### 📦 Latest Release (Phase 3)

This release introduces the biggest product leap in the repository:

- intelligent fraud detection system
- instant payout integration with Razorpay test mode
- zero-touch claim engine
- real-time environment simulation and override controls
- automated demo orchestration
- insurer dashboard with predictive analytics
- explainable AI flows across worker and insurer experiences
- stronger end-to-end storytelling for live judging

View all releases here:

- [GitHub Releases](https://github.com/Sanjay1712KSK/GuideWire/releases)

---

## 📄 Pitch Deck

View our pitch deck here:

- [Pitch Deck](./GigShield%20Final%20Pitch%20Deck%20PPT.pdf)

---

## 🧪 How To Run Locally

### Backend Setup

```bash
git clone https://github.com/Sanjay1712KSK/GuideWire.git
cd GuideWire/backend
pip install -r requirements.txt
uvicorn main:app --reload
```

Backend runs at:

```text
http://127.0.0.1:8000
```

### Frontend Setup

```bash
cd GuideWire
flutter pub get
flutter run --dart-define=API_BASE_URL=http://YOUR_LOCAL_IP:8000
```

Use:

- `http://10.0.2.2:8000` for Android emulator
- your machine LAN IP for a real phone on the same Wi-Fi

### Build APK

```bash
flutter build apk --release
```

### Environment Variables

Important environment variables include:

- `RAZORPAY_KEY_ID`
- `RAZORPAY_KEY_SECRET`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USER`
- `SMTP_PASS`
- `SENDER_EMAIL`
- `OPENWEATHER_API_KEY`
- `ORS_API_KEY`
- `DATABASE_URL`
- `API_PUBLIC_BASE_URL`
- `BLOCKCHAIN_MODE`

Reference:

- [backend/.env.example](backend/.env.example)

### Seed Demo Inputs

After the backend is running, you can enable simulation input:

```http
POST /simulate/input
Content-Type: application/json

{
  "enable_simulation": true,
  "regenerate_income": true,
  "days": 30
}
```

### Recommended Local Demo Flow

1. Start the backend.
2. Confirm `/health` is working.
3. Seed simulation input if needed.
4. Run the Flutter app with the correct API base URL.
5. Log in with a demo persona.
6. Walk through Home, Earnings, Insurance, Claims, and Admin.

---

## 🔐 Security & Trust Features

- bcrypt password hashing
- JWT-based authentication
- OTP verification support
- device binding
- session anomaly detection
- location-aware claim validation
- spoofing resistance signals
- fraud logs
- explainable fraud outcomes
- blockchain-backed event logging through adapter architecture

---

## 🧰 Tech Stack

- `Frontend`: Flutter, Riverpod, Geolocator, Local Auth, Secure Storage
- `Backend`: FastAPI, SQLAlchemy, Python services, JWT auth
- `Database`: SQLite for development, PostgreSQL-ready deployment
- `Integrations`: Open-Meteo, OpenWeather AQI, OpenRouteService, Brevo, Razorpay
- `Product Intelligence`: risk engine, premium engine, claim engine, fraud engine, prediction engine, payout service, admin analytics

---

## 📚 Documentation References

- [API specification](backend/docs/api_spec.md)
- [Actor demo guide](backend/docs/demo/actor_demo_guide.md)
- [Live demo runbook](backend/docs/live_demo_runbook.md)
- [Perfect demo script](backend/docs/perfect_demo_script.md)
- [Deployment notes](backend/docs/deployment_web.md)

---

## 🌟 Why GigShield Stands Out

- real-time environmental signals drive the insurance logic
- premium and claims reuse the same explainable risk foundation
- the platform protects both honest workers and insurers
- fraud prevention is built into the product, not bolted on
- the worker journey feels immediate and understandable
- the insurer experience goes beyond dashboards into actionable intelligence
- the demo system is reliable, visual, and presentation-friendly
- the product feels like an insurtech platform, not just a collection of screens

---

## 👥 Team

Built by Team CampTech for the Guidewire / DevTrails Hackathon.
