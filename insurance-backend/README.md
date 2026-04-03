# Insurance Backend — Risk, Fraud & Payout Modules

## Modules you built
| Module | Description | Owner |
|---|---|---|
| **Risk + Environment Engine** | Scores user risk from age, occupation, location zone, credit, claim history | You |
| **Fraud Detection** | Runs rule-based checks on every claim before payout | You |
| **Auto Payout (NBFLite)** | Queues and executes bank transfers, handles retries and webhooks | You |
| Premium Engine | Calculates policy premiums using risk score | Friend |
| Policy Management | Policy lifecycle, documents | Friend |
| Claim System | Claim filing and tracking | Friend |

---

## Quick Start (Today)

### 1. Install dependencies
```bash
npm install
```

### 2. Setup environment
```bash
cp .env.example .env
# Edit .env with your DB credentials
```

### 3. Start PostgreSQL and Redis
```bash
# If using Docker:
docker run -d --name pg -e POSTGRES_PASSWORD=yourpassword -p 5432:5432 postgres:15
docker run -d --name redis -p 6379:6379 redis:7
```

### 4. Create the database
```bash
psql -U postgres -c "CREATE DATABASE insurance_db;"
```

### 5. Run migrations
```bash
npm run migrate
```

### 6. Start the server
```bash
npm run dev
```

Server starts on **http://localhost:3000**

### 7. Run tests
```bash
npm test
```

---

## API Reference

### Risk Engine

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/api/risk/evaluate` | JWT | Evaluate and save risk for a user |
| GET | `/api/risk/user/:userId` | JWT | Get stored risk profile |
| GET | `/api/risk/zones` | JWT | List all environment zones |
| POST | `/api/risk/zones` | JWT + Admin | Create/update a zone |
| GET | `/api/risk/stats` | JWT + Admin | Risk distribution stats |
| POST | `/api/risk/internal/score` | Internal Key | Used by friend's premium engine |

**Evaluate risk example:**
```bash
curl -X POST http://localhost:3000/api/risk/evaluate \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user-uuid-here",
    "age": 32,
    "occupation": "software_developer",
    "creditScore": 720,
    "locationZone": "URBAN_LOW",
    "claimHistory": []
  }'
```

---

### Fraud Detection

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/api/fraud/check` | Internal Key | Run fraud check on a claim |
| GET | `/api/fraud/claim/:claimId` | JWT | Get fraud check result for a claim |
| GET | `/api/fraud/queue` | JWT + Admin | Manual review queue |
| PUT | `/api/fraud/:checkId/decision` | JWT + Admin | Admin approve or block |
| GET | `/api/fraud/stats` | JWT + Admin | Fraud statistics |

**Fraud check example (called by friend's claim system):**
```bash
curl -X POST http://localhost:3000/api/fraud/check \
  -H "x-internal-key: your_internal_key" \
  -H "Content-Type: application/json" \
  -d '{
    "claimId": "claim-uuid",
    "userId": "user-uuid",
    "amount": 75000,
    "claimType": "MOTOR",
    "policyId": "policy-uuid"
  }'
```

**Fraud status values:**
- `CLEAR` → auto-trigger payout
- `REVIEW` → low suspicion, queued for manual check
- `FLAGGED` → multiple flags, admin must approve before payout
- `BLOCKED` → auto-blocked, no payout

---

### Payout System

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/api/payouts/initiate` | Internal Key | Start a payout for approved claim |
| GET | `/api/payouts/claim/:claimId` | JWT | Check payout status |
| GET | `/api/payouts/:payoutId/audit` | JWT | Full audit trail |
| POST | `/api/payouts/:payoutId/retry` | JWT + Admin | Retry failed payout |
| GET | `/api/payouts` | JWT + Admin | List all payouts |
| GET | `/api/payouts/stats` | JWT + Admin | Payout statistics |
| POST | `/webhooks/nbflite` | NBFLite Sig | Webhook for bank settlement |

**Payout status flow:**
```
PENDING → PROCESSING → SUCCESS
                    ↘ FAILED → (retry) → PROCESSING
                                       ↘ PERMANENTLY_FAILED
```

---

## Integration with Friend's Modules

### What your modules expose to friend's modules

**1. Risk score for premium engine:**
```
POST /api/risk/internal/score
Header: x-internal-key: <INTERNAL_SERVICE_KEY>
Body: { "userId": "..." }
Returns: { riskScore, riskCategory, premiumMultiplier }
```

**2. Fraud check triggered by claim system:**
```
POST /api/fraud/check
Header: x-internal-key: <INTERNAL_SERVICE_KEY>
Body: { claimId, userId, amount, claimType, policyId }
```

**3. Payout notification to policy system** (you call their endpoint):
```
Set POLICY_SERVICE_URL in .env
Your payout module will POST to: <POLICY_SERVICE_URL>/internal/claim-paid
```

### Environment variables to share with friend
```
INTERNAL_SERVICE_KEY=agree_on_a_shared_secret
POLICY_SERVICE_URL=http://friend-service:3001
```

---

## NBFLite Integration

Currently running in **MOCK mode** (`NBFLITE_MOCK_MODE=true`).

To go live:
1. Set `NBFLITE_MOCK_MODE=false` in `.env`
2. Fill in `NBFLITE_API_URL` and `NBFLITE_API_KEY` with real credentials
3. Register your webhook URL with NBFLite: `https://yourdomain.com/webhooks/nbflite`
4. Set `NBFLITE_WEBHOOK_SECRET` for signature verification
5. Update `nbfliteClient.js` → `initiateTransfer` if their request body differs from the mock

---

## Payout Queue (Redis + Bull)

- Auto-retries failed transfers up to 3 times (exponential backoff: 5s, 10s, 20s)
- Jobs are deduplicated per payout ID
- Permanent failures after all retries are marked `PERMANENTLY_FAILED`
- Admin can manually retry via `POST /api/payouts/:id/retry`

Monitor queues with Bull Board (optional):
```bash
npm install @bull-board/express @bull-board/api
```

---

## File Structure
```
src/
├── app.js                          # Express app
├── server.js                       # Entry point + graceful shutdown
├── modules/
│   ├── risk-engine/
│   │   ├── riskCalculator.js       # Core scoring logic
│   │   ├── riskService.js          # DB operations
│   │   └── riskRoutes.js           # API routes
│   ├── fraud-detection/
│   │   ├── fraudRules.js           # All fraud rules
│   │   ├── fraudService.js         # DB + business logic
│   │   └── fraudRoutes.js          # API routes
│   └── payout/
│       ├── nbfliteClient.js        # NBFLite API + mock
│       ├── payoutService.js        # DB + business logic
│       └── payoutRoutes.js         # API routes + webhook
├── queues/
│   └── payoutQueue.js              # Bull queue + worker
└── shared/
    ├── db/index.js                 # PostgreSQL pool
    ├── middleware/
    │   ├── auth.js                 # JWT + internal key auth
    │   └── errorHandler.js         # Global error handling
    └── utils/index.js              # Shared helpers
migrations/
├── 001_initial.sql                 # All DB tables + seed zones
└── run.js                          # Migration runner
tests/
├── riskCalculator.test.js
├── fraudRules.test.js
└── payoutService.test.js
```
