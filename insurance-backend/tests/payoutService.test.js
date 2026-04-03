jest.mock('../src/shared/db', () => ({
  query: jest.fn(),
  transaction: jest.fn(),
}));
jest.mock('../src/queues/payoutQueue', () => ({
  enqueuePayout: jest.fn().mockResolvedValue('job-123'),
  getQueueStats: jest.fn().mockResolvedValue({ waiting: 0, active: 0, completed: 5, failed: 1, delayed: 0 }),
}));

const db = require('../src/shared/db');
const { enqueuePayout } = require('../src/queues/payoutQueue');
const payoutService = require('../src/modules/payout/payoutService');

describe('Payout Service', () => {

  beforeEach(() => jest.clearAllMocks());

  describe('initiatePayout', () => {
    it('creates a payout and enqueues it when no existing payout', async () => {
      // No existing payout
      db.query.mockResolvedValueOnce({ rows: [] });

      // User has bank details
      db.query.mockResolvedValueOnce({ rows: [{ bank_account: '123456789', bank_ifsc: 'HDFC0001' }] });

      // transaction mock: run callback immediately
      db.transaction.mockImplementation(async (cb) => {
        db.query
          .mockResolvedValueOnce({ rows: [{ id: 'payout-999', claim_id: 'claim-001', user_id: 'user-001', amount: 50000, currency: 'INR' }] })
          .mockResolvedValueOnce({ rows: [] }); // audit log insert
        return cb({ query: db.query });
      });

      const result = await payoutService.initiatePayout({
        claimId: 'claim-001',
        userId: 'user-001',
        amount: 50000,
      });

      expect(result.status).toBe('PENDING');
      expect(result.payoutId).toBeDefined();
      expect(enqueuePayout).toHaveBeenCalledTimes(1);
    });

    it('returns existing payout without re-enqueuing if one already exists', async () => {
      db.query.mockResolvedValueOnce({
        rows: [{ id: 'payout-existing', status: 'PROCESSING', claim_id: 'claim-001' }]
      });

      const result = await payoutService.initiatePayout({
        claimId: 'claim-001', userId: 'user-001', amount: 50000,
      });

      expect(result.existing).toBe(true);
      expect(enqueuePayout).not.toHaveBeenCalled();
    });
  });

  describe('retryPayout', () => {
    it('resets status and requeues for FAILED payout', async () => {
      db.query
        .mockResolvedValueOnce({ rows: [{ id: 'payout-001', status: 'FAILED' }] }) // fetch
        .mockResolvedValueOnce({ rows: [] }) // update status
        .mockResolvedValueOnce({ rows: [] }); // audit log

      const result = await payoutService.retryPayout('payout-001', 'admin-001');
      expect(result.status).toBe('PENDING');
      expect(enqueuePayout).toHaveBeenCalledWith('payout-001', 'high');
    });

    it('throws 400 if payout is not in FAILED state', async () => {
      db.query.mockResolvedValueOnce({ rows: [{ id: 'payout-001', status: 'SUCCESS' }] });

      await expect(payoutService.retryPayout('payout-001', 'admin-001'))
        .rejects.toMatchObject({ status: 400 });
    });

    it('throws 404 if payout not found', async () => {
      db.query.mockResolvedValueOnce({ rows: [] });

      await expect(payoutService.retryPayout('no-such-id', 'admin-001'))
        .rejects.toMatchObject({ status: 404 });
    });
  });

  describe('processWebhook', () => {
    it('marks payout SUCCESS on NBFLite success callback', async () => {
      db.query
        .mockResolvedValueOnce({ rows: [{ id: 'payout-001', claim_id: 'claim-001', user_id: 'user-001' }] })
        .mockResolvedValueOnce({ rows: [] }) // UPDATE payouts
        .mockResolvedValueOnce({ rows: [] }); // audit log

      const result = await payoutService.processWebhook({
        txnId: 'TXN-ABC123',
        status: 'SUCCESS',
        settledAt: new Date().toISOString(),
      });

      expect(result.handled).toBe(true);
      expect(result.payoutId).toBe('payout-001');
    });

    it('returns handled: false for unknown txn_id', async () => {
      db.query.mockResolvedValueOnce({ rows: [] });

      const result = await payoutService.processWebhook({ txnId: 'UNKNOWN', status: 'SUCCESS' });
      expect(result.handled).toBe(false);
    });

    it('marks payout FAILED on bank rejection', async () => {
      db.query
        .mockResolvedValueOnce({ rows: [{ id: 'payout-001', claim_id: 'claim-001' }] })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [] });

      const result = await payoutService.processWebhook({
        txnId: 'TXN-FAIL', status: 'FAILED', failureReason: 'Insufficient funds in beneficiary account',
      });

      expect(result.newStatus).toBe('FAILED');
    });
  });
});
