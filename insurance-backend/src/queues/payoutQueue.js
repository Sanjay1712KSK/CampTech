const Bull = require('bull');
const db = require('../shared/db');
const nbflite = require('../modules/payout/nbfliteClient');

const payoutQueue = new Bull('insurance-payouts', {
  redis: process.env.REDIS_URL || 'redis://localhost:6379',
  defaultJobOptions: {
    attempts: parseInt(process.env.PAYOUT_MAX_RETRIES) || 3,
    backoff: {
      type: 'exponential',
      delay: parseInt(process.env.PAYOUT_RETRY_DELAY_MS) || 5000,
    },
    removeOnComplete: false, // keep for audit
    removeOnFail: false,
  },
});

/**
 * Queue a payout job.
 */
const enqueuePayout = async (payoutId, priority = 'normal') => {
  const job = await payoutQueue.add(
    { payoutId },
    {
      priority: priority === 'high' ? 1 : 5,
      jobId: `payout-${payoutId}`, // deduplicate
    }
  );
  console.log(`[PayoutQueue] Enqueued payout ${payoutId}, job #${job.id}`);
  return job.id;
};

/**
 * Worker: process a payout job.
 */
payoutQueue.process(async (job) => {
  const { payoutId } = job.data;
  console.log(`[PayoutQueue] Processing payout ${payoutId} (attempt ${job.attemptsMade + 1})`);

  // Fetch payout + bank details
  const { rows } = await db.query(
    `SELECT p.*, u.bank_account, u.bank_ifsc, u.bank_name, u.mobile, u.full_name
     FROM payouts p
     LEFT JOIN users u ON u.id = p.user_id
     WHERE p.id = $1`,
    [payoutId]
  );

  if (!rows.length) throw new Error(`Payout ${payoutId} not found`);
  const payout = rows[0];

  if (payout.status === 'SUCCESS') {
    console.log(`[PayoutQueue] Payout ${payoutId} already succeeded, skipping`);
    return { skipped: true };
  }

  // Mark as processing
  await db.query(
    `UPDATE payouts SET status = 'PROCESSING', attempts = attempts + 1, last_attempt_at = NOW() WHERE id = $1`,
    [payoutId]
  );

  // Log the attempt
  await logAudit(payoutId, 'TRANSFER_INITIATED', { attempt: job.attemptsMade + 1 });

  try {
    const result = await nbflite.initiateTransfer({
      payoutId,
      userId: payout.user_id,
      amount: parseFloat(payout.amount),
      bankDetails: {
        accountNumber: payout.bank_account,
        ifsc: payout.bank_ifsc,
        name: payout.bank_name || payout.full_name,
        mobile: payout.mobile,
      },
    });

    // Store NBFLite response
    await db.query(
      `UPDATE payouts
       SET status = 'PROCESSING', nbflite_txn_id = $1, nbflite_response = $2, updated_at = NOW()
       WHERE id = $3`,
      [result.txn_id, JSON.stringify(result), payoutId]
    );

    await logAudit(payoutId, 'TRANSFER_SENT_TO_BANK', { txnId: result.txn_id });

    // In mock mode: simulate settlement after short delay
    if (process.env.NBFLITE_MOCK_MODE === 'true') {
      setTimeout(() => settleMockPayout(payoutId, result.txn_id), 3000);
    }

    return { txnId: result.txn_id };

  } catch (err) {
    await db.query(
      `UPDATE payouts SET status = 'FAILED', failure_reason = $1, updated_at = NOW() WHERE id = $2`,
      [err.message, payoutId]
    );
    await logAudit(payoutId, 'TRANSFER_FAILED', { error: err.message, attempt: job.attemptsMade + 1 });
    throw err; // rethrow so Bull retries
  }
});

// Auto-settle mock payouts for testing
const settleMockPayout = async (payoutId, txnId) => {
  try {
    const status = await nbflite.checkTransferStatus(txnId);
    if (status.status === 'SUCCESS') {
      await db.query(
        `UPDATE payouts SET status = 'SUCCESS', paid_at = NOW(), updated_at = NOW() WHERE id = $1`,
        [payoutId]
      );
      await logAudit(payoutId, 'PAYOUT_SETTLED', { txnId, mode: 'mock_auto_settle' });
      console.log(`[PayoutQueue] Mock payout ${payoutId} auto-settled`);
    }
  } catch (err) {
    console.error(`[PayoutQueue] Mock settle failed for ${payoutId}:`, err.message);
  }
};

// Event handlers
payoutQueue.on('completed', (job, result) => {
  if (!result?.skipped) {
    console.log(`[PayoutQueue] Job ${job.id} completed for payout ${job.data.payoutId}`);
  }
});

payoutQueue.on('failed', (job, err) => {
  console.error(`[PayoutQueue] Job ${job.id} failed (${job.attemptsMade}/${job.opts.attempts}):`, err.message);
  if (job.attemptsMade >= job.opts.attempts) {
    // Mark as permanently failed after all retries
    db.query(
      `UPDATE payouts SET status = 'PERMANENTLY_FAILED', updated_at = NOW() WHERE id = $1`,
      [job.data.payoutId]
    ).catch(console.error);
  }
});

payoutQueue.on('stalled', (job) => {
  console.warn(`[PayoutQueue] Job ${job.id} stalled - will be retried`);
});

const logAudit = async (payoutId, event, details = {}) => {
  await db.query(
    `INSERT INTO payout_audit_log (payout_id, event, details) VALUES ($1, $2, $3)`,
    [payoutId, event, JSON.stringify(details)]
  ).catch(err => console.error('Audit log failed:', err.message));
};

const getQueueStats = async () => {
  const [waiting, active, completed, failed, delayed] = await Promise.all([
    payoutQueue.getWaitingCount(),
    payoutQueue.getActiveCount(),
    payoutQueue.getCompletedCount(),
    payoutQueue.getFailedCount(),
    payoutQueue.getDelayedCount(),
  ]);
  return { waiting, active, completed, failed, delayed };
};

module.exports = { enqueuePayout, payoutQueue, getQueueStats };
