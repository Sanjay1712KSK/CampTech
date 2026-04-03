const { calculateRiskScore, riskToPremiumMultiplier } = require('../src/modules/risk-engine/riskCalculator');

describe('Risk Calculator', () => {

  describe('calculateRiskScore', () => {
    it('returns LOW for a young professional with clean history', () => {
      const result = calculateRiskScore({
        age: 32,
        occupation: 'software_developer',
        creditScore: 750,
        claimHistory: [],
        environmentScore: 0.1,
      });
      expect(result.score).toBeGreaterThanOrEqual(0);
      expect(result.score).toBeLessThan(0.5);
      expect(result.category).toBe('LOW');
    });

    it('returns HIGH or CRITICAL for a high-risk profile', () => {
      const result = calculateRiskScore({
        age: 22,
        occupation: 'miner',
        creditScore: 320,
        claimHistory: [
          { date: new Date(Date.now() - 10 * 86400000).toISOString(), fraudulent: false },
          { date: new Date(Date.now() - 20 * 86400000).toISOString(), fraudulent: true },
        ],
        environmentScore: 0.85,
      });
      expect(result.score).toBeGreaterThan(0.5);
      expect(['HIGH', 'CRITICAL']).toContain(result.category);
    });

    it('score is always between 0 and 1', () => {
      const extremeHigh = calculateRiskScore({
        age: 80, occupation: 'soldier', creditScore: 300,
        claimHistory: Array(10).fill({ date: new Date().toISOString(), fraudulent: true }),
        environmentScore: 1.0,
      });
      const extremeLow = calculateRiskScore({
        age: 35, occupation: 'researcher', creditScore: 850,
        claimHistory: [], environmentScore: 0.0,
      });
      expect(extremeHigh.score).toBeLessThanOrEqual(1.0);
      expect(extremeLow.score).toBeGreaterThanOrEqual(0.0);
    });

    it('returns all factor keys in output', () => {
      const result = calculateRiskScore({ age: 30, occupation: 'teacher', environmentScore: 0.3 });
      expect(result.factors).toHaveProperty('ageScore');
      expect(result.factors).toHaveProperty('occupationScore');
      expect(result.factors).toHaveProperty('historyScore');
      expect(result.factors).toHaveProperty('creditScoreVal');
      expect(result.factors).toHaveProperty('environmentScore');
    });

    it('handles unknown occupation with default score', () => {
      const result = calculateRiskScore({ age: 30, occupation: 'ninja', environmentScore: 0.3 });
      expect(result.score).toBeGreaterThan(0);
    });
  });

  describe('riskToPremiumMultiplier', () => {
    it('returns 1.0x for zero risk', () => {
      expect(riskToPremiumMultiplier(0)).toBe(1.0);
    });

    it('returns 2.5x for maximum risk', () => {
      expect(riskToPremiumMultiplier(1)).toBe(2.5);
    });

    it('returns a value between 1.0 and 2.5 for mid risk', () => {
      const m = riskToPremiumMultiplier(0.5);
      expect(m).toBeGreaterThan(1.0);
      expect(m).toBeLessThan(2.5);
    });
  });
});
