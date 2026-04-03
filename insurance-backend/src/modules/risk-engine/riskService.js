const db = require('../../shared/db');
const { calculateRiskScore, riskToPremiumMultiplier } = require('./riskCalculator');

/**
 * Evaluate risk for a user and persist the result.
 * Called by: premium engine (friend's module) or directly via API.
 */
const evaluateAndSaveRisk = async ({ userId, age, occupation, creditScore, claimHistory, assetAgeYears, locationZone }) => {
  // Fetch environment score for the zone
  let environmentScore = 0.3; // default
  if (locationZone) {
    const zoneResult = await db.query(
      'SELECT * FROM environment_zones WHERE zone_code = $1',
      [locationZone]
    );
    if (zoneResult.rows.length > 0) {
      const z = zoneResult.rows[0];
      // Composite environment score from zone factors
      environmentScore = (z.flood_risk * 0.35 + z.crime_index * 0.35 + z.natural_disaster_index * 0.30);
    }
  }

  const result = calculateRiskScore({ age, occupation, creditScore, claimHistory, assetAgeYears, environmentScore });
  const premiumMultiplier = riskToPremiumMultiplier(result.score);

  // Upsert risk profile (one per user, updated on re-evaluation)
  const { rows } = await db.query(
    `INSERT INTO risk_profiles (user_id, location_zone, environment_score, risk_score, risk_category, factors, premium_multiplier)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT (user_id) DO UPDATE
       SET location_zone = EXCLUDED.location_zone,
           environment_score = EXCLUDED.environment_score,
           risk_score = EXCLUDED.risk_score,
           risk_category = EXCLUDED.risk_category,
           factors = EXCLUDED.factors,
           premium_multiplier = EXCLUDED.premium_multiplier,
           updated_at = NOW()
     RETURNING *`,
    [userId, locationZone, result.factors.environmentScore, result.score, result.category, JSON.stringify(result.factors), premiumMultiplier]
  );

  return { ...rows[0], ...result, premiumMultiplier };
};

const getRiskProfile = async (userId) => {
  const { rows } = await db.query('SELECT * FROM risk_profiles WHERE user_id = $1', [userId]);
  if (!rows.length) return null;
  return rows[0];
};

const getAllZones = async () => {
  const { rows } = await db.query('SELECT * FROM environment_zones ORDER BY zone_code');
  return rows;
};

const upsertZone = async (zoneCode, { floodRisk, crimeIndex, naturalDisasterIndex, description }) => {
  const { rows } = await db.query(
    `INSERT INTO environment_zones (zone_code, flood_risk, crime_index, natural_disaster_index, description)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (zone_code) DO UPDATE
       SET flood_risk = EXCLUDED.flood_risk,
           crime_index = EXCLUDED.crime_index,
           natural_disaster_index = EXCLUDED.natural_disaster_index,
           description = EXCLUDED.description,
           updated_at = NOW()
     RETURNING *`,
    [zoneCode, floodRisk, crimeIndex, naturalDisasterIndex, description]
  );
  return rows[0];
};

const getRiskStats = async () => {
  const { rows } = await db.query(`
    SELECT
      risk_category,
      COUNT(*) as count,
      ROUND(AVG(risk_score)::numeric, 3) as avg_score,
      ROUND(AVG(premium_multiplier)::numeric, 3) as avg_multiplier
    FROM risk_profiles
    GROUP BY risk_category
    ORDER BY avg_score
  `);
  return rows;
};

module.exports = { evaluateAndSaveRisk, getRiskProfile, getAllZones, upsertZone, getRiskStats };
