# Gig Insurance Backend API Specification

This document defines the public API contract for the FastAPI backend used in the gig worker insurance system.

## Objectives

- Ensure frontend requests send valid data
- Prevent backend crashes through strict validation
- Standardize successful and failed responses
- Make debugging easier for developers and judges

## Validation Rules

The backend uses Pydantic validation on request bodies, query parameters, and response payloads.

### Core Rules

- `email` must be a valid email address
- `password` must be at least 8 characters
- `user_id` must be an integer greater than `0`
- `lat` must be a float between `-90` and `90`
- `lon` must be a float between `-180` and `180`
- Critical request fields are required and cannot be `null`
- Extra unexpected fields are rejected for documented request bodies

### Document Rules

- Aadhaar must contain exactly `12` digits
- License must contain `8` to `15` alphanumeric characters
- Name match is case-insensitive

## Standard Error Format

All request validation errors and backend errors return:

```json
{
  "error": true,
  "message": "Description"
}
```

Common examples:

```json
{
  "error": true,
  "message": "email: value is not a valid email address"
}
```

```json
{
  "error": true,
  "message": "Invalid credentials"
}
```

## 1. Auth APIs

### `POST /auth/signup`

Creates a new user account.

Request body:

```json
{
  "name": "string",
  "email": "valid email",
  "phone": "string",
  "password": "min 8 chars"
}
```

Example request:

```json
{
  "name": "Sanju",
  "email": "sanju@gmail.com",
  "phone": "9876543210",
  "password": "password123"
}
```

Success response: `201 Created`

```json
{
  "id": 1,
  "name": "Sanju",
  "email": "sanju@gmail.com",
  "phone": "9876543210",
  "is_verified": false
}
```

Validation notes:

- `name` minimum length: `2`
- `phone` must be exactly `10` digits
- Duplicate email returns an error

### `POST /auth/login`

Authenticates an existing user.

Request body:

```json
{
  "email": "sanju@gmail.com",
  "password": "password123"
}
```

Success response: `200 OK`

```json
{
  "id": 1,
  "name": "Sanju",
  "email": "sanju@gmail.com",
  "phone": "9876543210",
  "is_verified": false
}
```

Failure example:

```json
{
  "error": true,
  "message": "Invalid credentials"
}
```

## 2. DigiLocker APIs

### `POST /digilocker/request`

Creates a DigiLocker verification request for a user.

Request body:

```json
{
  "user_id": 1
}
```

Success response: `201 Created`

```json
{
  "request_id": "uuid",
  "status": "PENDING"
}
```

### `POST /digilocker/consent`

Submits DigiLocker consent details and verifies the document.

Request body:

```json
{
  "request_id": "uuid",
  "document_type": "aadhaar",
  "document_number": "123456789012",
  "name": "Sanju"
}
```

Valid input rules:

- Aadhaar: exactly `12` digits
- License: `8` to `15` alphanumeric characters
- Name: case-insensitive match against the verified document

Success response: `200 OK`

```json
{
  "status": "VERIFIED",
  "name": "Sanju",
  "document_type": "aadhaar"
}
```

Failure response: `200 OK`

```json
{
  "status": "FAILED",
  "reason": "Invalid document or mismatch"
}
```

Validation failure example:

```json
{
  "error": true,
  "message": "Value error, Invalid Aadhaar format"
}
```

## 3. Environment API

### `GET /environment?lat={lat}&lon={lon}`

Returns environmental context used by the risk engine.

Required query params:

- `lat`: float, example `13.0827`
- `lon`: float, example `80.2707`

Valid range:

- `lat`: `-90` to `90`
- `lon`: `-180` to `180`

Test input:

```text
/environment?lat=13.0827&lon=80.2707
```

Success response: `200 OK`

```json
{
  "weather": {
    "temperature": 31.2,
    "humidity": 72.4,
    "wind_speed": 6.8,
    "rainfall": 1.4
  },
  "aqi": {
    "aqi": 2,
    "pm2_5": 18.5,
    "pm10": 26.1
  },
  "traffic": {
    "traffic_score": 1.3,
    "traffic_level": "MEDIUM"
  },
  "context": {
    "hour": 18,
    "day_type": "weekday"
  }
}
```

## 4. Risk API

### `GET /risk?lat={lat}&lon={lon}&user_id={optional}`

Computes delivery risk for the provided location.

Inputs:

- `lat` required
- `lon` required
- `user_id` optional

Internal flow:

- Calls `/environment` logic internally
- Calls `risk_engine`
- Adds gig context if `user_id` is provided and income data exists

Success response: `200 OK`

```json
{
  "environment": {
    "weather": {
      "temperature": 31.2,
      "humidity": 72.4,
      "wind_speed": 6.8,
      "rainfall": 1.4
    },
    "aqi": {
      "aqi": 2,
      "pm2_5": 18.5,
      "pm10": 26.1
    },
    "traffic": {
      "traffic_score": 1.3,
      "traffic_level": "MEDIUM"
    },
    "context": {
      "hour": 18,
      "day_type": "weekday"
    }
  },
  "risk": {
    "risk_score": 0.72,
    "risk_level": "HIGH",
    "risk_factors": {
      "weather_risk": 0.8,
      "aqi_risk": 0.6,
      "traffic_risk": 0.8,
      "time_risk": 0.5
    },
    "recommendation": "Avoid delivery if possible"
  },
  "gig_context": {
    "earnings_today": 320,
    "orders_completed": 9
  }
}
```

Notes:

- `gig_context` is `null` when `user_id` is not supplied or data is unavailable
- `risk_score` is normalized between `0.0` and `1.0`
- `risk_level` is one of `LOW`, `MEDIUM`, `HIGH`

## 5. Gig Mock APIs

### `POST /gig/generate-data`

Generates mock income data for a user.

Request body:

```json
{
  "user_id": 1,
  "days": 30
}
```

Rules:

- `user_id` must be a positive integer
- `days` must be between `1` and `90`

Success response: `200 OK`

```json
{
  "generated": 30,
  "data": [
    {
      "date": "2026-03-01",
      "orders_completed": 18,
      "hours_worked": 8.0,
      "earnings": 720.0,
      "earnings_per_order": 40.0,
      "platform": "swiggy",
      "disruption_type": "none",
      "weather_condition": "clear",
      "temperature": 31.0,
      "humidity": 60.0,
      "rainfall": 0.0,
      "wind_speed": 6.0,
      "aqi_level": 2,
      "pm2_5": 18.0,
      "pm10": 27.0,
      "traffic_level": "LOW",
      "traffic_score": 1.0,
      "peak_hours_active": 5.0,
      "off_peak_hours": 3.0,
      "expected_orders": 18,
      "order_acceptance_rate": 0.96,
      "order_completion_rate": 0.97,
      "distance_travelled_km": 54.0,
      "avg_delivery_time_mins": 28.0,
      "earnings_per_hour": 90.0,
      "efficiency_score": 2.25,
      "loss_amount": 0.0,
      "earnings_variance": 0.0,
      "risk_score": 0.18,
      "is_weekend": false,
      "is_holiday": false,
      "city": "Chennai"
    }
  ]
}
```

### `GET /gig/income-history?user_id=1`

Success response: `200 OK`

```json
[
  {
    "date": "2026-03-01",
    "orders_completed": 18,
    "hours_worked": 8,
    "earnings": 720,
    "platform": "swiggy",
    "disruption_type": "none"
  }
]
```

### `GET /gig/today-income?user_id=1`

Success response: `200 OK`

```json
{
  "earnings": 312,
  "orders_completed": 9,
  "hours_worked": 6.5,
  "disruption_type": "rain"
}
```

### `GET /gig/baseline-income?user_id=1`

Success response: `200 OK`

```json
{
  "baseline_daily_income": 850
}
```

## cURL Examples

### Environment

```bash
curl "http://127.0.0.1:8000/environment?lat=13.0827&lon=80.2707"
```

### Risk

```bash
curl "http://127.0.0.1:8000/risk?lat=13.0827&lon=80.2707&user_id=1"
```

### DigiLocker Consent

```bash
curl -X POST "http://127.0.0.1:8000/digilocker/consent" \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "11111111-1111-1111-1111-111111111111",
    "document_type": "aadhaar",
    "document_number": "123456789012",
    "name": "Sanju"
  }'
```

### Gig Generate Data

```bash
curl -X POST "http://127.0.0.1:8000/gig/generate-data" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "days": 30
  }'
```

## Developer Notes

- Request bodies reject undocumented extra fields
- Query parameters are range-validated before service execution
- Response models validate outgoing data to reduce contract drift
- Global exception handlers convert validation and runtime failures into a single error shape
- This contract is intended to keep frontend integration predictable and reduce debugging time
