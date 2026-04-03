const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin, authenticateInternal } = require('../../shared/middleware/auth');
const { asyncHandler } = require('../../shared/middleware/errorHandler');
const { validate } = require('../../shared/utils');
const riskService = require('./riskService');

/**
 * POST /api/risk/evaluate
 * Evaluate and save risk for a user.
 * Called by: frontend onboarding, or friend's premium engine (internal).
 */
router.post('/evaluate', authenticate, asyncHandler(async (req, res) => {
  const { userId, age, occupation, creditScore, claimHistory, assetAgeYears, locationZone } = req.body;
  validate(['userId', 'age', 'occupation'], req.body);

  if (age < 0 || age > 120) {
    return res.status(400).json({ error: 'Invalid age' });
  }

  const result = await riskService.evaluateAndSaveRisk({
    userId, age: parseInt(age), occupation, creditScore, claimHistory, assetAgeYears, locationZone
  });

  res.status(200).json({
    success: true,
    data: result,
    message: `Risk evaluated: ${result.category} (score: ${result.score})`
  });
}));

/**
 * GET /api/risk/user/:userId
 * Get stored risk profile for a user.
 */
router.get('/user/:userId', authenticate, asyncHandler(async (req, res) => {
  const profile = await riskService.getRiskProfile(req.params.userId);
  if (!profile) {
    return res.status(404).json({ error: 'Risk profile not found. Run /evaluate first.' });
  }
  res.json({ success: true, data: profile });
}));

/**
 * GET /api/risk/zones
 * List all environment zones.
 */
router.get('/zones', authenticate, asyncHandler(async (req, res) => {
  const zones = await riskService.getAllZones();
  res.json({ success: true, data: zones, count: zones.length });
}));

/**
 * POST /api/risk/zones
 * Create or update an environment zone (admin only).
 */
router.post('/zones', authenticate, requireAdmin, asyncHandler(async (req, res) => {
  const { zoneCode, floodRisk, crimeIndex, naturalDisasterIndex, description } = req.body;
  validate(['zoneCode', 'floodRisk', 'crimeIndex', 'naturalDisasterIndex'], req.body);

  const zone = await riskService.upsertZone(zoneCode, { floodRisk, crimeIndex, naturalDisasterIndex, description });
  res.status(201).json({ success: true, data: zone });
}));

/**
 * GET /api/risk/stats
 * Risk distribution stats (admin).
 */
router.get('/stats', authenticate, requireAdmin, asyncHandler(async (req, res) => {
  const stats = await riskService.getRiskStats();
  res.json({ success: true, data: stats });
}));

/**
 * POST /api/risk/internal/score
 * Internal endpoint for friend's premium engine to get a risk score.
 * No JWT needed — uses internal service key.
 */
router.post('/internal/score', authenticateInternal, asyncHandler(async (req, res) => {
  const { userId } = req.body;
  validate(['userId'], req.body);

  const profile = await riskService.getRiskProfile(userId);
  if (!profile) {
    return res.status(404).json({ error: 'Risk profile not found' });
  }

  // Return just what premium engine needs
  res.json({
    success: true,
    data: {
      userId: profile.user_id,
      riskScore: profile.risk_score,
      riskCategory: profile.risk_category,
      premiumMultiplier: profile.premium_multiplier,
    }
  });
}));

module.exports = router;
