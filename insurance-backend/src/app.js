require('dotenv').config();
const express = require('express');
const app = express();

// ── Middleware ──────────────────────────────────────────────
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Request logger (dev)
if (process.env.NODE_ENV !== 'test') {
  app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
    next();
  });
}

// ── Health check ────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'insurance-backend',
    modules: ['risk-engine', 'fraud-detection', 'payout'],
    timestamp: new Date().toISOString(),
  });
});

// ── Module Routes ───────────────────────────────────────────
const riskRoutes                      = require('./modules/risk-engine/riskRoutes');
const fraudRoutes                     = require('./modules/fraud-detection/fraudRoutes');
const { router: payoutRoutes,
        webhookHandler }              = require('./modules/payout/payoutRoutes');

app.use('/api/risk',   riskRoutes);
app.use('/api/fraud',  fraudRoutes);
app.use('/api/payouts', payoutRoutes);

// NBFLite webhook (raw path, no /api prefix — matches what you register with NBFLite)
app.post('/webhooks/nbflite', webhookHandler);

// ── Error handling ──────────────────────────────────────────
const { errorHandler, notFound } = require('./shared/middleware/errorHandler');
app.use(notFound);
app.use(errorHandler);

module.exports = app;
