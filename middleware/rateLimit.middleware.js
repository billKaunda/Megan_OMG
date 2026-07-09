const rateLimit = require('express-rate-limit');

/**
 * General API limiter – 100 requests per minute per IP.
 * Applied globally to all /api routes.
 */
const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Too many requests, please try again later.' },
});

/**
 * Stricter limiter for write operations (transactions, mining).
 * 20 requests per minute per IP.
 */
const writeLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Too many write requests, please slow down.' },
});

module.exports = { apiLimiter, writeLimiter };
