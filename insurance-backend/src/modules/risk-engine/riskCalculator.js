const { clamp, round } = require('../../shared/utils');

// Occupation risk lookup table
const OCCUPATION_RISK = {
  // High risk
  miner: 0.9, pilot: 0.8, firefighter: 0.85, police: 0.8,
  soldier: 0.9, construction_worker: 0.75, fisherman: 0.7,
  // Medium risk
  driver: 0.55, nurse: 0.5, doctor: 0.4, teacher: 0.3,
  engineer: 0.3, accountant: 0.25, manager: 0.25,
  // Low risk
  software_developer: 0.15, researcher: 0.15, office_worker: 0.2,
  retired: 0.3, student: 0.25,
  // Default for unknown
  default: 0.4,
};

// Claim history scoring: more recent/frequent claims = higher risk
const scoreClaimHistory = (claims = []) => {
  if (!claims.length) return 0;
  const now = Date.now();
  let score = 0;
  for (const claim of claims) {
    const ageInDays = (now - new Date(claim.date).getTime()) / 86400000;
    const recencyWeight = ageInDays < 90 ? 1.0 : ageInDays < 365 ? 0.6 : 0.3;
    score += recencyWeight * (claim.fraudulent ? 0.5 : 0.15);
  }
  return clamp(score);
};

// Age scoring: young (<25) and elderly (>65) are higher risk
const scoreAge = (age) => {
  if (age < 18) return 0.9;
  if (age < 25) return 0.75;
  if (age < 40) return 0.2;
  if (age < 55) return 0.25;
  if (age < 65) return 0.4;
  return 0.65;
};

// Credit score scoring (300-850 range, higher = less risky)
const scoreCreditScore = (creditScore) => {
  if (!creditScore) return 0.5; // unknown
  return clamp(1 - (creditScore - 300) / 550);
};

// Vehicle/asset age scoring (for motor/property insurance)
const scoreAssetAge = (assetAgeYears) => {
  if (assetAgeYears === undefined || assetAgeYears === null) return 0;
  if (assetAgeYears > 15) return 0.8;
  if (assetAgeYears > 10) return 0.6;
  if (assetAgeYears > 5) return 0.35;
  return 0.15;
};

/**
 * Main risk calculation function.
 * Weights:
 *   - Location/environment zone: 30%
 *   - Claim history:             25%
 *   - Occupation:                20%
 *   - Age:                       15%
 *   - Credit score:              10%
 *
 * Optional modifiers:
 *   - Asset age (motor/property): adds up to 0.1 boost
 */
const calculateRiskScore = ({ age, occupation, claimHistory = [], creditScore, assetAgeYears, environmentScore = 0.3 }) => {
  const ageScore        = scoreAge(age);
  const occupationScore = OCCUPATION_RISK[occupation?.toLowerCase()] ?? OCCUPATION_RISK.default;
  const historyScore    = scoreClaimHistory(claimHistory);
  const creditScoreVal  = scoreCreditScore(creditScore);
  const assetScore      = scoreAssetAge(assetAgeYears);

  const composite = clamp(
    environmentScore  * 0.30 +
    historyScore      * 0.25 +
    occupationScore   * 0.20 +
    ageScore          * 0.15 +
    creditScoreVal    * 0.10 +
    assetScore        * 0.10  // bonus modifier
  );

  const category =
    composite < 0.25 ? 'LOW' :
    composite < 0.50 ? 'MEDIUM' :
    composite < 0.75 ? 'HIGH' : 'CRITICAL';

  return {
    score: round(composite),
    category,
    factors: {
      environmentScore: round(environmentScore),
      historyScore:     round(historyScore),
      occupationScore:  round(occupationScore),
      ageScore:         round(ageScore),
      creditScoreVal:   round(creditScoreVal),
      assetScore:       round(assetScore),
    },
  };
};

// Invert risk score to a premium loading multiplier (1.0x = no loading, 2.5x = max)
const riskToPremiumMultiplier = (riskScore) => {
  return round(1.0 + riskScore * 1.5, 2);
};

module.exports = { calculateRiskScore, riskToPremiumMultiplier, OCCUPATION_RISK };
