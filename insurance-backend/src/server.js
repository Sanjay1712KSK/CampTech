require('dotenv').config();
const app = require('./app');

// Boot the payout queue worker
require('./queues/payoutQueue');

const PORT = process.env.PORT || 3000;

const server = app.listen(PORT, () => {
  console.log('');
  console.log('╔══════════════════════════════════════════╗');
  console.log('║     Insurance Backend - Started          ║');
  console.log('╠══════════════════════════════════════════╣');
  console.log(`║  Port    : ${PORT}                           ║`);
  console.log(`║  Mode    : ${process.env.NODE_ENV || 'development'}                  ║`);
  console.log(`║  NBFLite : ${process.env.NBFLITE_MOCK_MODE === 'true' ? 'MOCK (safe to test)' : 'LIVE'}          ║`);
  console.log('╠══════════════════════════════════════════╣');
  console.log('║  Modules:                                ║');
  console.log('║  ✓ Risk + Environment Engine             ║');
  console.log('║  ✓ Fraud Detection                       ║');
  console.log('║  ✓ Auto Payout (NBFLite)                 ║');
  console.log('╚══════════════════════════════════════════╝');
  console.log('');
});

// Graceful shutdown
const shutdown = async (signal) => {
  console.log(`\n[Server] ${signal} received. Shutting down gracefully...`);
  server.close(async () => {
    const { payoutQueue } = require('./queues/payoutQueue');
    await payoutQueue.close();
    const { pool } = require('./shared/db');
    await pool.end();
    console.log('[Server] All connections closed. Bye.');
    process.exit(0);
  });
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT',  () => shutdown('SIGINT'));
process.on('unhandledRejection', (reason) => {
  console.error('[Server] Unhandled rejection:', reason);
});
