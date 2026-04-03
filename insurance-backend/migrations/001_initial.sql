-- ============================================================
-- Insurance Platform - Complete DB Migration
-- Run: psql -d insurance_db -f migrations/001_initial.sql
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- MODULE 1: Risk + Environment Engine
-- ============================================================

CREATE TABLE IF NOT EXISTS environment_zones (
  zone_code            VARCHAR(50)   PRIMARY KEY,
  flood_risk           FLOAT         NOT NULL DEFAULT 0.0 CHECK (flood_risk BETWEEN 0 AND 1),
  crime_index          FLOAT         NOT NULL DEFAULT 0.0 CHECK (crime_index BETWEEN 0 AND 1),
  natural_disaster_index FLOAT       NOT NULL DEFAULT 0.0 CHECK (natural_disaster_index BETWEEN 0 AND 1),
  description          TEXT,
  created_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS risk_profiles (
  id                   UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID          NOT NULL UNIQUE,
  location_zone        VARCHAR(50)   REFERENCES environment_zones(zone_code),
  environment_score    FLOAT         NOT NULL DEFAULT 0.3,
  risk_score           FLOAT         NOT NULL CHECK (risk_score BETWEEN 0 AND 1),
  risk_category        VARCHAR(20)   NOT NULL CHECK (risk_category IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  premium_multiplier   FLOAT         NOT NULL DEFAULT 1.0,
  factors              JSONB,
  created_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_risk_profiles_user_id   ON risk_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_risk_profiles_category  ON risk_profiles(risk_category);

-- ============================================================
-- MODULE 2: Fraud Detection
-- ============================================================

-- claims table (may already exist in friend's schema — adjust as needed)
CREATE TABLE IF NOT EXISTS claims (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        NOT NULL,
  policy_id    UUID,
  claim_type   VARCHAR(50) NOT NULL,
  amount       DECIMAL(12,2) NOT NULL CHECK (amount > 0),
  description  TEXT,
  status       VARCHAR(30) NOT NULL DEFAULT 'PENDING',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fraud_checks (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id     UUID        NOT NULL REFERENCES claims(id),
  user_id      UUID        NOT NULL,
  fraud_score  FLOAT       NOT NULL CHECK (fraud_score BETWEEN 0 AND 1),
  flags        JSONB,
  status       VARCHAR(30) NOT NULL CHECK (status IN ('CLEAR','REVIEW','FLAGGED','BLOCKED','CLEARED_BY_ADMIN')),
  review_notes TEXT,
  reviewed_by  UUID,
  reviewed_at  TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fraud_checks_claim_id  ON fraud_checks(claim_id);
CREATE INDEX IF NOT EXISTS idx_fraud_checks_user_id   ON fraud_checks(user_id);
CREATE INDEX IF NOT EXISTS idx_fraud_checks_status    ON fraud_checks(status);

-- Trigger table for payout initiation after admin approval
CREATE TABLE IF NOT EXISTS payout_triggers (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id        UUID        NOT NULL UNIQUE,
  fraud_check_id  UUID        REFERENCES fraud_checks(id),
  triggered_by    VARCHAR(50) NOT NULL DEFAULT 'auto',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- MODULE 3: Automatic Payout + NBFLite
-- ============================================================

-- users table (minimal — extend as needed; friend's module may own this)
CREATE TABLE IF NOT EXISTS users (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name     VARCHAR(200),
  mobile        VARCHAR(15),
  bank_account  VARCHAR(30),
  bank_ifsc     VARCHAR(15),
  bank_name     VARCHAR(100),
  role          VARCHAR(20)  NOT NULL DEFAULT 'customer',
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payouts (
  id                UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id          UUID          NOT NULL UNIQUE,
  user_id           UUID          NOT NULL,
  amount            DECIMAL(12,2) NOT NULL CHECK (amount > 0),
  currency          VARCHAR(3)    NOT NULL DEFAULT 'INR',
  status            VARCHAR(30)   NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING','PROCESSING','SUCCESS','FAILED','RETRYING','PERMANENTLY_FAILED')),
  nbflite_txn_id    VARCHAR(100),
  nbflite_response  JSONB,
  triggered_by      VARCHAR(50)   DEFAULT 'auto',
  attempts          INT           NOT NULL DEFAULT 0,
  last_attempt_at   TIMESTAMPTZ,
  paid_at           TIMESTAMPTZ,
  failure_reason    TEXT,
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payouts_claim_id       ON payouts(claim_id);
CREATE INDEX IF NOT EXISTS idx_payouts_user_id        ON payouts(user_id);
CREATE INDEX IF NOT EXISTS idx_payouts_status         ON payouts(status);
CREATE INDEX IF NOT EXISTS idx_payouts_nbflite_txn    ON payouts(nbflite_txn_id) WHERE nbflite_txn_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS payout_audit_log (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  payout_id   UUID        NOT NULL REFERENCES payouts(id),
  event       VARCHAR(50) NOT NULL,
  details     JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_payout_id ON payout_audit_log(payout_id);

-- ============================================================
-- Seed data: sample environment zones
-- ============================================================

INSERT INTO environment_zones (zone_code, flood_risk, crime_index, natural_disaster_index, description) VALUES
  ('URBAN_LOW',    0.10, 0.20, 0.05, 'Urban area with low flood and crime risk'),
  ('URBAN_HIGH',   0.25, 0.70, 0.10, 'Urban area with high crime index'),
  ('COASTAL_HIGH', 0.85, 0.30, 0.75, 'Coastal zone — high flood and cyclone risk'),
  ('FLOOD_ZONE_A', 0.90, 0.20, 0.80, 'FEMA-equivalent high flood zone'),
  ('RURAL_LOW',    0.15, 0.10, 0.15, 'Rural area with minimal risk'),
  ('HILL_STATION', 0.30, 0.05, 0.45, 'Hill area — landslide and earthquake risk'),
  ('INDUSTRIAL',   0.20, 0.40, 0.10, 'Industrial zone with moderate risk')
ON CONFLICT (zone_code) DO NOTHING;
