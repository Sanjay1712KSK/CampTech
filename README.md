# GigShield — AI-Powered Income Protection for Gig Workers  (Guidewire - DevTrails Hackathon)
###  Built by Team CampTech

---

##  Problem Statement

Gig workers face unpredictable income loss due to external disruptions such as weather, traffic, and environmental conditions, with no existing safety net for daily wage loss.

---

## Persona & Scenarios

### Target Persona:
Food delivery partners (Swiggy / Zomato)

### Key Scenarios:
- 🌧 Heavy rain → deliveries reduced → income loss  
- 🚦 High traffic → fewer orders completed  
- 🌫 Poor AQI → unsafe working conditions  
- ❌ Normal day → no claim triggered  

---

##  Workflow Overview

1. User logs in and connects gig account  
2. System fetches real-time location + environmental data  
3. Risk Engine computes risk score  
4. Premium Engine generates weekly premium  
5. User subscribes to policy  
6. Disruption occurs → income drops  
7. Claim Engine detects loss  
8. Fraud checks are performed  
9. Payout is processed  

---

## 💰 Weekly Premium Model

- Premium is calculated **weekly** to match gig worker payout cycles  
- Based on:
  - Risk score (weather, traffic, AQI)
  - User income patterns  

### Behavior:
- High-risk week → higher premium  
- Low-risk week → lower premium  

### Why Weekly?
Gig workers earn weekly → pricing aligns with their real cash flow, making it practical and affordable.

---

## Parametric Triggers

Claims are triggered automatically when:

- Rainfall exceeds threshold  
- Traffic congestion is high  
- AQI reaches unsafe levels  
- External disruptions reduce delivery activity  

---

## Core Engines

### Risk Engine
Calculates real-time risk using weather, AQI, traffic, and location data  

### Premium Engine
Generates dynamic weekly pricing based on risk and income  

### Claim Engine
Detects income loss and triggers payouts automatically  

---

## Fraud Detection Strategy

Integrated within claim processing:

- Location validation  
- Weather verification  
- Activity pattern analysis  
- Duplicate claim detection  

---

## AI/ML Integration Plan

- Predictive risk modeling using historical data  
- Adaptive premium pricing  
- Behavior-based fraud detection  
- Personalized insurance recommendations  

---

## Blockchain Integration

NBFLite is used to:

- Store policies, claims, and payouts  
- Ensure tamper-proof records  
- Provide transparency  

---

## Platform Choice

We chose a **Mobile-first approach** because:

- Gig workers primarily operate via smartphones  
- Real-time location tracking is essential  
- Faster adoption and accessibility  

---

## Tech Stack

### Frontend
Flutter, Riverpod, Geolocator, Local Auth  

### Backend
FastAPI, Python, (SQLAlchemy,SQLite - For Backend prototype), Will be upgraded to PostgreSQL 

Note: SQLite is used for prototyping. The system is designed to scale to PostgreSQL in production.

### APIs
Open-Meteo, OpenWeather, OpenRouteService  

### Security
NBFLite Blockchain, DigiLocker (Mock), Biometrics  

---

## Development Plan

- Phase 1: Prototype with real-time APIs and mock data  
- Phase 2: Automation of claims and pricing  
- Phase 3: ML integration and scaling  

---

## Current Status

- Functional prototype  
- Real-time risk calculation  
- Weekly pricing model  
- Claim simulation with fraud detection  
- Blockchain integration  

---

## Innovation

- Fully automated parametric insurance  
- Weekly pricing aligned with gig economy  
- AI-driven risk + pricing + claims  
- Blockchain-backed transparency. 

---

## Demo

👉 [Add your 2-minute demo link]

---

## Conclusion

GigShield creates a real-time, intelligent safety net for gig workers, protecting income dynamically using AI, automation, and blockchain.
