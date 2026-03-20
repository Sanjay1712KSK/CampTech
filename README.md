# 🚀 AI-Powered Parametric Insurance for Gig Workers

## 📌 Problem Statement

Gig workers (Swiggy, Zomato delivery partners) face unpredictable income loss due to external disruptions such as weather, traffic, and environmental conditions.  

Currently, there is no system that protects their **daily income loss**, forcing them to bear financial risks without any safety net.

---

## 💡 Our Solution

We propose an **AI-powered parametric insurance platform** that:

- Predicts real-time risk using environmental and behavioral data
- Calculates **dynamic weekly premiums**
- Automatically detects income loss and processes claims
- Ensures secure and transparent operations using **NBFLite blockchain**

---

## 🎯 Persona Focus

- Target Users: **Food delivery partners (Swiggy/Zomato)**
- Coverage Scope: **Loss of income only**
- Pricing Model: **Weekly (aligned with gig payout cycles)**

---

## ⚙️ System Architecture (Core Engines)

Our platform is powered by three interconnected engines:

### 🧠 1. Risk Engine
- Uses real-time APIs:
  - Weather (Open-Meteo)
  - AQI (OpenWeather)
  - Traffic (OpenRouteService)
- Computes a **dynamic risk score** based on location and conditions

---

### 💰 2. Premium Engine
- Converts risk into a **dynamic weekly premium**
- Adapts based on:
  - User income patterns
  - Environmental risk levels
- Ensures fair and flexible pricing aligned with gig workers’ weekly earnings

---

### ⚡ 3. Claim Engine
- Detects income loss using:
  - Gig income data
  - Environmental disruptions
- Automatically triggers payouts
- Integrates **fraud detection before approval**

---

## 🛡 Fraud Detection (Integrated)

Fraud detection is embedded within the system:

- 📍 Location validation (geo-consistency)
- 🌧 Weather verification (real vs claimed)
- 📊 Activity pattern analysis
- 🔁 Duplicate claim prevention

---

## 🔗 Blockchain Integration

We use **NBFLite blockchain** to:

- Record policies, claims, and payouts
- Ensure **tamper-proof verification**
- Maintain transparency and trust

---

## 🔄 Parametric Triggers

Claims are triggered automatically when:

- Rainfall exceeds threshold
- Traffic congestion is high
- AQI levels are unsafe
- Environmental disruptions reduce delivery activity

---

## 📱 Workflow Overview

1. User logs in and connects gig account  
2. System fetches **real-time location + environmental data**  
3. Risk Engine computes risk score  
4. Premium Engine generates weekly premium  
5. User subscribes to policy  
6. Claim Engine detects disruption and income loss  
7. Fraud checks are performed  
8. Payout is processed securely  

---

## 🤖 AI/ML Roadmap

The system is designed to evolve with ML:

- Predictive risk modeling using historical data  
- Adaptive premium pricing  
- Behavior-based fraud detection  
- Personalized insurance recommendations  

---

## 🛠 Tech Stack

### Frontend
- Flutter (Mobile App)
- Riverpod (State Management)

### Backend
- FastAPI
- SQLite (Mock DB)

### APIs
- Open-Meteo (Weather)
- OpenWeather (AQI)
- OpenRouteService (Traffic)

### Security & Infra
- NBFLite Blockchain
- Biometric Authentication

---

## 📊 Current Status (Phase 1)

- ✅ Functional prototype with real-time APIs  
- ✅ Mock gig data integration  
- ✅ Risk + Premium + Claim engines (demo logic)  
- ✅ Fraud detection simulation  
- ✅ Blockchain integration (NBFLite)  

---

## 🚀 Future Scope

- Full ML model integration  
- Real gig platform APIs  
- Production-grade payment systems  
- Advanced fraud detection (GPS spoofing, anomaly detection)  

---

## 🎥 Demo

👉 [Add your 2-minute video link here]

---

## 📌 Conclusion

This platform creates a **real-time, intelligent safety net for gig workers**, protecting their income dynamically using AI, automation, and blockchain.
