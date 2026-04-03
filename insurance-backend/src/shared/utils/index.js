const { v4: uuidv4 } = require('uuid');

// Normalize a value between 0 and 1
const normalize = (value, min, max) => {
  if (max === min) return 0;
  return Math.max(0, Math.min(1, (value - min) / (max - min)));
};

// Clamp a value between min and max
const clamp = (value, min = 0, max = 1) => Math.max(min, Math.min(max, value));

// Round to N decimal places
const round = (value, decimals = 3) => parseFloat(value.toFixed(decimals));

// Generate a unique reference ID with prefix
const generateRef = (prefix = 'REF') => `${prefix}-${Date.now()}-${uuidv4().split('-')[0].toUpperCase()}`;

// Simple input validation
const validate = (fields, body) => {
  const missing = fields.filter(f => body[f] === undefined || body[f] === null || body[f] === '');
  if (missing.length > 0) {
    const err = new Error(`Missing required fields: ${missing.join(', ')}`);
    err.name = 'ValidationError';
    throw err;
  }
};

// Paginate query results
const paginate = (req) => {
  const page = Math.max(1, parseInt(req.query.page) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
  const offset = (page - 1) * limit;
  return { page, limit, offset };
};

// Format paginated response
const paginatedResponse = (data, total, page, limit) => ({
  data,
  pagination: {
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit),
    hasNext: page * limit < total,
    hasPrev: page > 1,
  }
});

// Sleep utility for retry delays
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

module.exports = { normalize, clamp, round, generateRef, validate, paginate, paginatedResponse, sleep };
