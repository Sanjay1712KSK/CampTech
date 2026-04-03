const db = require('../../shared/db');
const { runFraudRules } = require('./fraudRules');
const { paginate, paginatedResponse } = require('../../shared/utils');

const THRESHOLDS = {
  REVIEW:  parseFloat(process.env.FRAUD_REVIEW_THRESHOLD  || '0.3'),
  FLAGGED: parseFloat(process.env.FRAUD_FLAGGED_THRESHOLD || '0.6'),
  BLOCKED: parseFloat(process.env.FRAUD_BLOCKED_THRESHOLD || '0.8'),
};

const scoreToStatus = (score) => {
  if (score >= THRESHOLDS.BLOCKED) return 'BLOCKED';
  if (score >= THRESHOLDS.FLAGGED) return 'FLAGGED';
  if (score >= THRESHOLDS.REVIEW)  return 'REVIEW';
  return 'CLEAR';
};

/**
 * Run a full fraud check on a claim and save the result.
 * Returns: { fraudScore, status, checkId }
 */
const runFraudCheck = async ({ claimId, userId, amount, claimType, policyId }) => {
  const { fraudScore, triggeredRules, allRules } = await runFraudRules({
    claimId, userId, amount, claimType, policyId
  });

  const status = scoreToStatus(fraudScore);

  const { rows } = await db.query(
    `INSERT INTO fraud_checks (claim_id, user_id, fraud_score, flags, status)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [claimId, userId, fraudScore, JSON.stringify({ triggered: triggeredRules, all: allRules }), status]
  );

  const check = rows[0];

  // If BLOCKED, auto-update the claim status as well
  if (status === 'BLOCKED') {
    await db.query(
      `UPDATE claims SET status = 'FRAUD_BLOCKED', updated_at = NOW() WHERE id = $1`,
      [claimId]
    ).catch(() => {}); // non-fatal if claims table is managed by friend
  }

  return {
    checkId: check.id,
    claimId,
    fraudScore,
    status,
    triggeredRules,
    message: getStatusMessage(status),
  };
};

const getStatusMessage = (status) => ({
  CLEAR:   'Claim passed all fraud checks. Proceed to payout.',
  REVIEW:  'Low-level flags detected. Queued for manual review.',
  FLAGGED: 'Multiple fraud indicators. Requires admin approval before payout.',
  BLOCKED: 'High fraud risk detected. Claim automatically blocked.',
}[status]);

/**
 * Admin: get the review queue (REVIEW + FLAGGED claims)
 */
const getReviewQueue = async (req) => {
  const { limit, offset, page } = paginate(req);
  const statusFilter = req.query.status || 'REVIEW,FLAGGED';
  const statuses = statusFilter.split(',').map(s => s.trim().toUpperCase());

  const { rows: data } = await db.query(
    `SELECT fc.*, c.amount, c.claim_type, c.description as claim_description
     FROM fraud_checks fc
     LEFT JOIN claims c ON c.id = fc.claim_id
     WHERE fc.status = ANY($1) AND fc.reviewed_at IS NULL
     ORDER BY fc.fraud_score DESC, fc.created_at ASC
     LIMIT $2 OFFSET $3`,
    [statuses, limit, offset]
  );

  const { rows: countRows } = await db.query(
    `SELECT COUNT(*) FROM fraud_checks WHERE status = ANY($1) AND reviewed_at IS NULL`,
    [statuses]
  );

  return paginatedResponse(data, parseInt(countRows[0].count), page, limit);
};

/**
 * Admin: approve or block a fraud check after manual review.
 * Decision: 'APPROVE' | 'BLOCK'
 */
const submitDecision = async (checkId, { decision, adminId, notes }) => {
  const finalStatus = decision === 'APPROVE' ? 'CLEARED_BY_ADMIN' : 'BLOCKED';

  const { rows } = await db.query(
    `UPDATE fraud_checks
     SET status = $1, reviewed_by = $2, reviewed_at = NOW(), review_notes = $3
     WHERE id = $4
     RETURNING *`,
    [finalStatus, adminId, notes, checkId]
  );

  if (!rows.length) throw Object.assign(new Error('Fraud check not found'), { status: 404 });

  const check = rows[0];

  // If approved, trigger payout queue
  if (decision === 'APPROVE') {
    // Emit event for payout module to pick up
    await db.query(
      `INSERT INTO payout_triggers (claim_id, fraud_check_id, triggered_by)
       VALUES ($1, $2, 'admin_approval')
       ON CONFLICT (claim_id) DO NOTHING`,
      [check.claim_id, checkId]
    ).catch(() => {});
  }

  return rows[0];
};

/**
 * Get fraud check by claim ID
 */
const getCheckByClaim = async (claimId) => {
  const { rows } = await db.query(
    'SELECT * FROM fraud_checks WHERE claim_id = $1 ORDER BY created_at DESC LIMIT 1',
    [claimId]
  );
  return rows[0] || null;
};

/**
 * Fraud stats for admin dashboard
 */
const getFraudStats = async () => {
  const { rows } = await db.query(`
    SELECT
      status,
      COUNT(*) as count,
      ROUND(AVG(fraud_score)::numeric, 3) as avg_score,
      ROUND(SUM(CASE WHEN c.amount IS NOT NULL THEN c.amount ELSE 0 END)::numeric, 2) as total_amount_at_risk
    FROM fraud_checks fc
    LEFT JOIN claims c ON c.id = fc.claim_id
    GROUP BY status
    ORDER BY count DESC
  `);

  const { rows: dailyRows } = await db.query(`
    SELECT DATE(created_at) as date, COUNT(*) as checks, SUM(CASE WHEN status IN ('FLAGGED','BLOCKED') THEN 1 ELSE 0 END) as flagged
    FROM fraud_checks
    WHERE created_at > NOW() - INTERVAL '30 days'
    GROUP BY DATE(created_at)
    ORDER BY date DESC
  `);

  return { byStatus: rows, daily: dailyRows };
};

module.exports = { runFraudCheck, getReviewQueue, submitDecision, getCheckByClaim, getFraudStats };
