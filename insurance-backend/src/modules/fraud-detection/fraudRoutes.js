const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin, authenticateInternal } = require('../../shared/middleware/auth');
const { asyncHandler } = require('../../shared/middleware/errorHandler');
const { validate } = require('../../shared/utils');
const fraudService = require('./fraudService');

/**
 * POST /api/fraud/check
 * Run a fraud check on a claim.
 * Called by: friend's claim system (internal) or your payout module.
 */
router.post('/check', authenticateInternal, asyncHandler(async (req, res) => {
  const { claimId, userId, amount, claimType, policyId } = req.body;
  validate(['claimId', 'userId', 'amount', 'claimType'], req.body);

  if (amount <= 0) {
    return res.status(400).json({ error: 'Amount must be positive' });
  }

  const result = await fraudService.runFraudCheck({ claimId, userId, amount: parseFloat(amount), claimType, policyId });

  const statusCode = result.status === 'BLOCKED' ? 200 : 200;
  res.status(statusCode).json({ success: true, data: result });
}));

/**
 * GET /api/fraud/claim/:claimId
 * Get the latest fraud check for a specific claim.
 */
router.get('/claim/:claimId', authenticate, asyncHandler(async (req, res) => {
  const check = await fraudService.getCheckByClaim(req.params.claimId);
  if (!check) {
    return res.status(404).json({ error: 'No fraud check found for this claim' });
  }
  res.json({ success: true, data: check });
}));

/**
 * GET /api/fraud/queue
 * Admin: view the manual review queue.
 * Query params: ?status=REVIEW,FLAGGED&page=1&limit=20
 */
router.get('/queue', authenticate, requireAdmin, asyncHandler(async (req, res) => {
  const result = await fraudService.getReviewQueue(req);
  res.json({ success: true, ...result });
}));

/**
 * PUT /api/fraud/:checkId/decision
 * Admin: approve or block a claim after manual review.
 * Body: { decision: 'APPROVE' | 'BLOCK', notes: '...' }
 */
router.put('/:checkId/decision', authenticate, requireAdmin, asyncHandler(async (req, res) => {
  const { decision, notes } = req.body;

  if (!['APPROVE', 'BLOCK'].includes(decision)) {
    return res.status(400).json({ error: 'Decision must be APPROVE or BLOCK' });
  }

  const result = await fraudService.submitDecision(req.params.checkId, {
    decision,
    adminId: req.user.id,
    notes,
  });

  res.json({
    success: true,
    data: result,
    message: decision === 'APPROVE'
      ? 'Claim approved. Payout will be triggered automatically.'
      : 'Claim blocked by admin.'
  });
}));

/**
 * GET /api/fraud/stats
 * Admin: fraud statistics dashboard.
 */
router.get('/stats', authenticate, requireAdmin, asyncHandler(async (req, res) => {
  const stats = await fraudService.getFraudStats();
  res.json({ success: true, data: stats });
}));

module.exports = router;
