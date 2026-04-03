const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin, authenticateInternal } = require('../../shared/middleware/auth');
const { asyncHandler } = require('../../shared/middleware/errorHandler');
const { validate } = require('../../shared/utils');
const payoutService = require('./payoutService');
const { validateWebhookSignature } = require('./nbfliteClient');
const { getQueueStats } = require('../../queues/payoutQueue');

/**
 * POST /api/payouts/initiate
 * Initiate a payout for an approved claim.
 * Called by: fraud module after CLEAR, or after admin approval.
 */
router.post('/initiate', authenticateInternal, asyncHandler(async (req, res) => {
  const { claimId, userId, amount, currency, triggeredBy } = req.body;
  validate(['claimId', 'userId', 'amount'], req.body);

  if (parseFloat(amount) <= 0) {
    return res.status(400).json({ error: 'Amount must be positive' });
  }

  const result = await payoutService.initiatePayout({
    claimId, userId, amount: parseFloat(amount), currency, triggeredBy
  });

  res.status(result.existing ? 200 : 201).json({ success: true, data: result });
}));

/**
 * GET /api/payouts/claim/:claimId
 * Get payout status for a claim.
 */
router.get('/claim/:claimId', authenticate, asyncHandler(async (req, res) => {
  const payout = await payoutService.getPayoutByClaim(req.params.claimId);
  if (!payout) {
    return res.status(404).json({ error: 'No payout found for this claim' });
  }
  res.json({ success: true, data: payout });
}));

/**
 * GET /api/payouts/:payoutId/audit
 * Get full audit trail for a payout.
 */
router.get('/:payoutId/audit', authenticate, asyncHandler(async (req, res) => {
  const result = await payoutService.getPayoutAudit(req.params.payoutId);
  if (!result) {
    return res.status(404).json({ error: 'Payout not found' });
  }
  res.json({ success: true, data: result });
}));

/**
 * POST /api/payouts/:payoutId/retry
 * Admin: manually retry a failed payout.
 */
router.post('/:payoutId/retry', authenticate, requireAdmin, asyncHandler(async (req, res) => {
  const result = await payoutService.retryPayout(req.params.payoutId, req.user.id);
  res.json({ success: true, data: result });
}));

/**
 * GET /api/payouts
 * Admin: list all payouts with filters.
 * Query: ?status=FAILED&userId=xxx&page=1&limit=20
 */
router.get('/', authenticate, requireAdmin, asyncHandler(async (req, res) => {
  const result = await payoutService.listPayouts(req);
  res.json({ success: true, ...result });
}));

/**
 * GET /api/payouts/stats
 * Admin: payout statistics.
 */
router.get('/stats', authenticate, requireAdmin, asyncHandler(async (req, res) => {
  const [stats, queueStats] = await Promise.all([
    payoutService.getPayoutStats(),
    getQueueStats(),
  ]);
  res.json({ success: true, data: { payouts: stats, queue: queueStats } });
}));

/**
 * POST /webhooks/nbflite
 * NBFLite calls this when a transfer settles (success or failure).
 * Note: mounted at root level in app.js, not under /api/payouts
 */
const webhookHandler = asyncHandler(async (req, res) => {
  const signature = req.headers['x-nbflite-signature'];

  // Validate webhook authenticity
  if (!validateWebhookSignature(req.body, signature)) {
    console.warn('[Webhook] Invalid NBFLite signature rejected');
    return res.status(401).json({ error: 'Invalid signature' });
  }

  const { txn_id, status, failure_reason, settled_at } = req.body;

  if (!txn_id || !status) {
    return res.status(400).json({ error: 'Missing txn_id or status' });
  }

  const result = await payoutService.processWebhook({
    txnId: txn_id,
    status: status.toUpperCase(),
    failureReason: failure_reason,
    settledAt: settled_at,
  });

  // Always respond 200 quickly — NBFLite will retry on non-200
  res.status(200).json({ received: true, ...result });
});

module.exports = { router, webhookHandler };
