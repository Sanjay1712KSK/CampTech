const { v4: uuidv4 } = require('uuid');
const db = require('../../shared/db');
const { enqueuePayout } = require('../../queues/payoutQueue');
const { paginate, paginatedResponse } = require('../../shared/utils');

/**
 * Initiate a payout for an approved claim.
 * Called automatically after fraud check CLEAR, or after admin approval.
 */
const initiatePayout = async ({ claimId, userId, amount, currency = 'INR', triggeredBy = 'auto' }) => {
  // Check for existing payout to prevent duplicates
  const existing = await db.query(
    `SELECT * FROM payouts WHERE claim_id = $1 AND status NOT IN ('FAILED', 'PERMANENTLY_FAILED')`,
    [claimId]
  );
  if (existing.rows.length > 0) {
    const p = existing.rows[0];
    return { payoutId: p.id, status: p.status, message: 'Payout already exists for this claim', existing: true };
  }

  // Validate user has bank details
  const userRes = await db.query(
    'SELECT bank_account, bank_ifsc FROM users WHERE id = $1',
    [userId]
  ).catch(() => ({ rows: [{}] })); // graceful if users table managed by friend

  if (userRes.rows[0] && !userRes.rows[0].bank_account) {
    throw Object.assign(
      new Error('User does not have bank account details on file. Cannot process payout.'),
      { status: 422 }
    );
  }

  return db.transaction(async (client) => {
    // Create the payout record
    const { rows } = await client.query(
      `INSERT INTO payouts (id, claim_id, user_id, amount, currency, status, triggered_by)
       VALUES ($1, $2, $3, $4, $5, 'PENDING', $6)
       RETURNING *`,
      [uuidv4(), claimId, userId, amount, currency, triggeredBy]
    );
    const payout = rows[0];

    // Log creation
    await client.query(
      `INSERT INTO payout_audit_log (payout_id, event, details)
       VALUES ($1, 'PAYOUT_CREATED', $2)`,
      [payout.id, JSON.stringify({ claimId, amount, triggeredBy })]
    );

    // Add to processing queue
    await enqueuePayout(payout.id);

    return {
      payoutId: payout.id,
      claimId,
      amount,
      currency,
      status: 'PENDING',
      message: 'Payout initiated and queued for processing',
    };
  });
};

/**
 * Get payout status for a claim.
 */
const getPayoutByClaim = async (claimId) => {
  const { rows } = await db.query(
    `SELECT p.*, al.event as last_event, al.created_at as last_event_at
     FROM payouts p
     LEFT JOIN payout_audit_log al ON al.payout_id = p.id
     WHERE p.claim_id = $1
     ORDER BY al.created_at DESC
     LIMIT 1`,
    [claimId]
  );
  return rows[0] || null;
};

/**
 * Get full audit trail for a payout.
 */
const getPayoutAudit = async (payoutId) => {
  const { rows: payout } = await db.query('SELECT * FROM payouts WHERE id = $1', [payoutId]);
  if (!payout.length) return null;

  const { rows: audit } = await db.query(
    'SELECT * FROM payout_audit_log WHERE payout_id = $1 ORDER BY created_at ASC',
    [payoutId]
  );

  return { payout: payout[0], auditTrail: audit };
};

/**
 * Manually retry a failed payout (admin action).
 */
const retryPayout = async (payoutId, adminId) => {
  const { rows } = await db.query('SELECT * FROM payouts WHERE id = $1', [payoutId]);
  if (!rows.length) throw Object.assign(new Error('Payout not found'), { status: 404 });

  const payout = rows[0];
  if (!['FAILED', 'PERMANENTLY_FAILED'].includes(payout.status)) {
    throw Object.assign(new Error(`Cannot retry payout with status: ${payout.status}`), { status: 400 });
  }

  // Reset status to PENDING and requeue
  await db.query(
    `UPDATE payouts SET status = 'PENDING', failure_reason = NULL, updated_at = NOW() WHERE id = $1`,
    [payoutId]
  );

  await db.query(
    `INSERT INTO payout_audit_log (payout_id, event, details) VALUES ($1, 'MANUAL_RETRY', $2)`,
    [payoutId, JSON.stringify({ retriedBy: adminId })]
  );

  await enqueuePayout(payoutId, 'high');

  return { payoutId, status: 'PENDING', message: 'Payout requeued for retry' };
};

/**
 * Handle NBFLite webhook: update payout status when bank confirms.
 */
const processWebhook = async ({ txnId, status, failureReason, settledAt }) => {
  const { rows } = await db.query(
    'SELECT * FROM payouts WHERE nbflite_txn_id = $1',
    [txnId]
  );

  if (!rows.length) {
    console.warn(`[Webhook] Unknown txn_id: ${txnId}`);
    return { handled: false };
  }

  const payout = rows[0];

  if (status === 'SUCCESS') {
    await db.query(
      `UPDATE payouts SET status = 'SUCCESS', paid_at = $1, updated_at = NOW() WHERE id = $2`,
      [settledAt || new Date(), payout.id]
    );
    await db.query(
      `INSERT INTO payout_audit_log (payout_id, event, details) VALUES ($1, 'PAYOUT_SETTLED', $2)`,
      [payout.id, JSON.stringify({ txnId, settledAt })]
    );
    // Notify friend's policy module of successful payout
    await notifyPolicyModule(payout.claim_id, 'PAID').catch(console.error);

  } else if (status === 'FAILED') {
    await db.query(
      `UPDATE payouts SET status = 'FAILED', failure_reason = $1, updated_at = NOW() WHERE id = $2`,
      [failureReason, payout.id]
    );
    await db.query(
      `INSERT INTO payout_audit_log (payout_id, event, details) VALUES ($1, 'BANK_REJECTED', $2)`,
      [payout.id, JSON.stringify({ txnId, failureReason })]
    );
  }

  return { handled: true, payoutId: payout.id, newStatus: status };
};

// Notify friend's policy management module (HTTP call or shared event)
const notifyPolicyModule = async (claimId, paymentStatus) => {
  const axios = require('axios');
  const POLICY_SERVICE = process.env.POLICY_SERVICE_URL;
  if (!POLICY_SERVICE) return;

  await axios.post(`${POLICY_SERVICE}/internal/claim-paid`, {
    claimId, paymentStatus
  }, {
    headers: { 'x-internal-key': process.env.INTERNAL_SERVICE_KEY },
    timeout: 5000,
  });
};

/**
 * Admin: list all payouts with filters.
 */
const listPayouts = async (req) => {
  const { limit, offset, page } = paginate(req);
  const { status, userId } = req.query;

  let whereClause = 'WHERE 1=1';
  const params = [];

  if (status) {
    params.push(status.toUpperCase());
    whereClause += ` AND p.status = $${params.length}`;
  }
  if (userId) {
    params.push(userId);
    whereClause += ` AND p.user_id = $${params.length}`;
  }

  params.push(limit, offset);
  const { rows: data } = await db.query(
    `SELECT p.* FROM payouts p ${whereClause} ORDER BY p.created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params
  );

  const countParams = params.slice(0, -2);
  const { rows: countRows } = await db.query(
    `SELECT COUNT(*) FROM payouts p ${whereClause}`,
    countParams
  );

  return paginatedResponse(data, parseInt(countRows[0].count), page, limit);
};

const getPayoutStats = async () => {
  const { rows } = await db.query(`
    SELECT
      status,
      COUNT(*) as count,
      ROUND(SUM(amount)::numeric, 2) as total_amount,
      ROUND(AVG(amount)::numeric, 2) as avg_amount
    FROM payouts
    GROUP BY status
    ORDER BY total_amount DESC
  `);
  return rows;
};

module.exports = { initiatePayout, getPayoutByClaim, getPayoutAudit, retryPayout, processWebhook, listPayouts, getPayoutStats };
