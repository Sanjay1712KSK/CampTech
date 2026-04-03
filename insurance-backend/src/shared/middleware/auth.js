const jwt = require('jsonwebtoken');

const authenticate = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer <token>

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(403).json({ error: 'Invalid or expired token' });
  }
};

const requireAdmin = (req, res, next) => {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
};

// For internal service-to-service calls (between your modules and friend's modules)
const authenticateInternal = (req, res, next) => {
  const key = req.headers['x-internal-key'];
  if (key !== process.env.INTERNAL_SERVICE_KEY) {
    return res.status(401).json({ error: 'Invalid internal service key' });
  }
  next();
};

module.exports = { authenticate, requireAdmin, authenticateInternal };
