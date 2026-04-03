const db = require('../../shared/db');
const { clamp } = require('../../shared/utils');

/**
 * Each rule returns a score between 0 (clean) and 1 (very suspicious).
 * Rules are run in parallel for speed.
 */
const FRAUD_RULES = [
  {
    name: 'duplicate_claim_same_type',
    description: 'User filed same type of claim within 30 days',
    weight: 0.65,
    check: async (claim) => {
      const { rows } = await db.query(
        `SELECT COUNT(*) FROM claims
         WHERE user_id = $1 AND claim_type = $2
           AND created_at > NOW() - INTERVAL '30 days'
           AND id != $3`,
        [claim.userId, claim.claimType, claim.claimId]
      );
      return parseInt(rows[0].count) > 0 ? 1 : 0;
    }
  },

  {
    name: 'high_amount_first_claim',
    description: 'Large claim amount on user\'s very first claim',
    weight: 0.70,
    check: async (claim) => {
      const { rows } = await db.query(
        'SELECT COUNT(*) FROM claims WHERE user_id = $1',
        [claim.userId]
      );
      const isFirst = parseInt(rows[0].count) <= 1;
      return isFirst && claim.amount > 50000 ? 1 : 0;
    }
  },

  {
    name: 'new_policy_large_claim',
    description: 'Large claim within 30 days of policy creation',
    weight: 0.60,
    check: async (claim) => {
      if (!claim.policyId) return 0;
      const { rows } = await db.query(
        'SELECT created_at FROM policies WHERE id = $1',
        [claim.policyId]
      );
      if (!rows.length) return 0;
      const daysSince = (Date.now() - new Date(rows[0].created_at).getTime()) / 86400000;
      return daysSince < 30 && claim.amount > 20000 ? 1 : 0;
    }
  },

  {
    name: 'velocity_check',
    description: '3 or more claims filed within 7 days',
    weight: 0.80,
    check: async (claim) => {
      const { rows } = await db.query(
        `SELECT COUNT(*) FROM claims
         WHERE user_id = $1 AND created_at > NOW() - INTERVAL '7 days'`,
        [claim.userId]
      );
      const count = parseInt(rows[0].count);
      if (count >= 5) return 1.0;
      if (count >= 3) return 0.6;
      return 0;
    }
  },

  {
    name: 'high_risk_user',
    description: 'User has a CRITICAL risk score from risk engine',
    weight: 0.45,
    check: async (claim) => {
      const { rows } = await db.query(
        'SELECT risk_category, risk_score FROM risk_profiles WHERE user_id = $1',
        [claim.userId]
      );
      if (!rows.length) return 0.2; // unknown = slight flag
      const cat = rows[0].risk_category;
      if (cat === 'CRITICAL') return 1.0;
      if (cat === 'HIGH')     return 0.5;
      return 0;
    }
  },

  {
    name: 'amount_spike',
    description: 'Claim amount is 3x higher than user\'s average',
    weight: 0.55,
    check: async (claim) => {
      const { rows } = await db.query(
        `SELECT AVG(amount) as avg_amount FROM claims
         WHERE user_id = $1 AND status != 'REJECTED'`,
        [claim.userId]
      );
      const avg = parseFloat(rows[0].avg_amount);
      if (!avg || isNaN(avg)) return 0;
      return claim.amount > avg * 3 ? 1 : 0;
    }
  },

  {
    name: 'previously_flagged_user',
    description: 'User had a prior FLAGGED or BLOCKED fraud check',
    weight: 0.75,
    check: async (claim) => {
      const { rows } = await db.query(
        `SELECT COUNT(*) FROM fraud_checks
         WHERE user_id = $1 AND status IN ('FLAGGED', 'BLOCKED')`,
        [claim.userId]
      );
      const count = parseInt(rows[0].count);
      if (count >= 2) return 1.0;
      if (count === 1) return 0.6;
      return 0;
    }
  },

  {
    name: 'nighttime_filing',
    description: 'Claim filed between 1am-4am (unusual hours)',
    weight: 0.20,
    check: async (claim) => {
      const hour = new Date().getHours();
      return (hour >= 1 && hour <= 4) ? 0.5 : 0;
    }
  },
];

/**
 * Run all fraud rules against a claim.
 * Returns weighted composite score + triggered rule names.
 */
const runFraudRules = async (claim) => {
  const results = await Promise.allSettled(
    FRAUD_RULES.map(rule =>
      rule.check(claim)
        .then(score => ({ name: rule.name, score, weight: rule.weight, description: rule.description }))
        .catch(err => {
          console.error(`Fraud rule ${rule.name} failed:`, err.message);
          return { name: rule.name, score: 0, weight: rule.weight, error: err.message };
        })
    )
  );

  const ruleResults = results.map(r => r.value || r.reason);
  const triggered = ruleResults.filter(r => r.score > 0);

  // Weighted average of triggered rules
  const totalWeight = triggered.reduce((sum, r) => sum + r.weight, 0);
  const weightedScore = totalWeight > 0
    ? triggered.reduce((sum, r) => sum + r.score * r.weight, 0) / totalWeight
    : 0;

  // Boost score slightly if multiple rules triggered
  const multipleRulesBoost = triggered.length > 2 ? 0.1 : 0;
  const finalScore = clamp(weightedScore + multipleRulesBoost);

  return {
    fraudScore: parseFloat(finalScore.toFixed(3)),
    triggeredRules: triggered.map(r => ({ name: r.name, description: r.description, score: r.score })),
    allRules: ruleResults,
  };
};

module.exports = { runFraudRules, FRAUD_RULES };
