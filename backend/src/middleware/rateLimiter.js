'use strict';

/**
 * src/middleware/rateLimiter.js
 * Rate-limiting middleware using express-rate-limit.
 *
 *  aiRateLimiter     — 30 requests / minute  (for AI endpoints)
 *  generalRateLimiter — 100 requests / minute (for all other endpoints)
 */

const rateLimit = require('express-rate-limit');

/**
 * Builds a standardised rate-limit error response body.
 */
function buildRateLimitHandler(limitName) {
  return (req, res) => {
    res.status(429).json({
      error: 'TooManyRequests',
      message: `Rate limit exceeded (${limitName}). Please slow down and try again later.`,
      retryAfter: res.getHeader('Retry-After'),
    });
  };
}

/** 30 requests per minute — applied to /api/ai/* routes. */
const aiRateLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 30,
  standardHeaders: true,  // Return rate limit info in `RateLimit-*` headers
  legacyHeaders: false,
  handler: buildRateLimitHandler('AI: 30 req/min'),
  keyGenerator: (req) => req.uid || req.ip, // key per authenticated user
});

/** 100 requests per minute — applied globally. */
const generalRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  handler: buildRateLimitHandler('General: 100 req/min'),
  keyGenerator: (req) => req.uid || req.ip,
});

module.exports = { aiRateLimiter, generalRateLimiter };
