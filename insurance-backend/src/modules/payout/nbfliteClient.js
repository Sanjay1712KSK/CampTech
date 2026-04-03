const axios = require('axios');
const { v4: uuidv4 } = require('uuid');

const MOCK_MODE = process.env.NBFLITE_MOCK_MODE === 'true';

/**
 * Mock NBFLite responses for development/testing.
 * Simulates 90% success, 10% failure to test retry logic.
 */
const mockTransfer = async ({ payoutId, amount }) => {
  await new Promise(r => setTimeout(r, 300)); // simulate network latency

  const willFail = Math.random() < 0.10; // 10% failure rate in mock
  if (willFail) {
    throw Object.assign(new Error('NBFLite mock: bank rejected transfer'), { code: 'BANK_REJECTED' });
  }

  return {
    txn_id: `MOCK-TXN-${uuidv4().toUpperCase()}`,
    reference_id: payoutId,
    status: 'PROCESSING',
    amount,
    currency: 'INR',
    mode: 'IMPS',
    estimated_settlement: new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString(), // 2h from now
    message: 'Transfer initiated successfully (MOCK)',
  };
};

const mockStatusCheck = async (txnId) => {
  await new Promise(r => setTimeout(r, 200));
  // In mock, 80% chance it's settled by the time we check
  const settled = Math.random() < 0.80;
  return {
    txn_id: txnId,
    status: settled ? 'SUCCESS' : 'PROCESSING',
    settled_at: settled ? new Date().toISOString() : null,
  };
};

/**
 * Initiate a bank transfer via NBFLite.
 */
const initiateTransfer = async ({ payoutId, userId, amount, bankDetails }) => {
  if (MOCK_MODE) {
    console.log(`[NBFLite MOCK] Initiating transfer: ₹${amount} for payout ${payoutId}`);
    return mockTransfer({ payoutId, amount });
  }

  const response = await axios.post(
    `${process.env.NBFLITE_API_URL}/transfers`,
    {
      reference_id: payoutId,
      beneficiary_account: bankDetails.accountNumber,
      beneficiary_ifsc: bankDetails.ifsc,
      beneficiary_name: bankDetails.name,
      beneficiary_mobile: bankDetails.mobile,
      amount: amount,
      currency: 'INR',
      transfer_mode: amount > 200000 ? 'RTGS' : 'IMPS', // RTGS for large amounts
      remarks: `Insurance claim payout | Ref: ${payoutId}`,
      webhook_url: `${process.env.APP_BASE_URL}/webhooks/nbflite`,
    },
    {
      headers: {
        'x-api-key': process.env.NBFLITE_API_KEY,
        'Content-Type': 'application/json',
      },
      timeout: 15000,
    }
  );

  return response.data;
};

/**
 * Check the status of an existing NBFLite transfer.
 */
const checkTransferStatus = async (txnId) => {
  if (MOCK_MODE) {
    return mockStatusCheck(txnId);
  }

  const response = await axios.get(
    `${process.env.NBFLITE_API_URL}/transfers/${txnId}`,
    {
      headers: { 'x-api-key': process.env.NBFLITE_API_KEY },
      timeout: 10000,
    }
  );

  return response.data;
};

/**
 * Validate NBFLite webhook signature.
 * Replace with actual signature verification when you have their docs.
 */
const validateWebhookSignature = (payload, signature, secret) => {
  if (MOCK_MODE) return true;
  const crypto = require('crypto');
  const expected = crypto
    .createHmac('sha256', secret || process.env.NBFLITE_WEBHOOK_SECRET)
    .update(JSON.stringify(payload))
    .digest('hex');
  return signature === `sha256=${expected}`;
};

module.exports = { initiateTransfer, checkTransferStatus, validateWebhookSignature };
