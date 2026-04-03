// Mock the DB so fraud rules run without a real Postgres connection
jest.mock('../src/shared/db', () => ({
  query: jest.fn(),
}));

const db = require('../src/shared/db');
const { runFraudRules } = require('../src/modules/fraud-detection/fraudRules');

// Helper to set up db.query mock responses in order
const mockDbResponses = (...responses) => {
  let callIndex = 0;
  db.query.mockImplementation(() => {
    const res = responses[callIndex % responses.length];
    callIndex++;
    return Promise.resolve(res);
  });
};

const baseClaim = {
  claimId: 'claim-001',
  userId:  'user-001',
  amount:  10000,
  claimType: 'MOTOR',
  policyId: 'policy-001',
};

describe('Fraud Rules Engine', () => {

  beforeEach(() => jest.clearAllMocks());

  it('returns CLEAR for a clean, first-time small claim', async () => {
    // Mock all DB calls to return "nothing suspicious"
    db.query.mockResolvedValue({ rows: [{ count: '0', avg_amount: null }] });

    const result = await runFraudRules({ ...baseClaim, amount: 5000 });
    expect(result.fraudScore).toBeLessThan(0.3);
    expect(result.triggeredRules.length).toBe(0);
  });

  it('flags velocity: 3+ claims in 7 days', async () => {
    db.query.mockImplementation((sql) => {
      if (sql.includes('7 days')) return Promise.resolve({ rows: [{ count: '4' }] });
      return Promise.resolve({ rows: [{ count: '0', avg_amount: null }] });
    });

    const result = await runFraudRules(baseClaim);
    const triggered = result.triggeredRules.map(r => r.name);
    expect(triggered).toContain('velocity_check');
    expect(result.fraudScore).toBeGreaterThan(0);
  });

  it('flags high amount on first claim', async () => {
    db.query.mockImplementation((sql) => {
      // claim count = 1 (this is the first claim), all others return 0
      if (sql.includes('SELECT COUNT(*) FROM claims WHERE user_id')) {
        return Promise.resolve({ rows: [{ count: '1' }] });
      }
      return Promise.resolve({ rows: [{ count: '0', avg_amount: null }] });
    });

    const result = await runFraudRules({ ...baseClaim, amount: 80000 });
    const triggered = result.triggeredRules.map(r => r.name);
    expect(triggered).toContain('high_amount_first_claim');
  });

  it('flags previously flagged user', async () => {
    db.query.mockImplementation((sql) => {
      if (sql.includes("IN ('FLAGGED', 'BLOCKED')")) {
        return Promise.resolve({ rows: [{ count: '2' }] });
      }
      return Promise.resolve({ rows: [{ count: '0', avg_amount: null }] });
    });

    const result = await runFraudRules(baseClaim);
    const triggered = result.triggeredRules.map(r => r.name);
    expect(triggered).toContain('previously_flagged_user');
  });

  it('fraud score is always between 0 and 1', async () => {
    // Make every rule return maximum suspicion
    db.query.mockResolvedValue({ rows: [{ count: '99', avg_amount: '100' }] });

    const result = await runFraudRules({ ...baseClaim, amount: 999999 });
    expect(result.fraudScore).toBeGreaterThanOrEqual(0);
    expect(result.fraudScore).toBeLessThanOrEqual(1);
  });

  it('continues if one rule throws an error', async () => {
    let callCount = 0;
    db.query.mockImplementation(() => {
      callCount++;
      if (callCount === 1) throw new Error('DB timeout');
      return Promise.resolve({ rows: [{ count: '0', avg_amount: null }] });
    });

    // Should not throw — errored rules return 0 score
    const result = await runFraudRules(baseClaim);
    expect(result).toHaveProperty('fraudScore');
  });
});
