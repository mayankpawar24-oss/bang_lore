'use strict';

/**
 * src/middleware/auth.js
 * Express middleware that verifies a Firebase ID token sent in the
 * `Authorization: Bearer <token>` header.
 *
 * On success: attaches req.uid = decodedToken.uid and calls next().
 * On failure: responds with 401 JSON error — NEVER calls next().
 *
 * The uid on req is the single source of truth for the caller's identity;
 * never trust a patientId sent in the request body or params for
 * ownership-sensitive operations.
 */

const { auth } = require('../config/firebase');
const logger = require('../utils/logger');

/**
 * Verify Firebase ID token middleware.
 */
async function verifyToken(req, res, next) {
  try {
    const authHeader = req.headers.authorization || '';

    if (!authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Missing or malformed Authorization header. Expected: Bearer <token>',
      });
    }

    const idToken = authHeader.slice(7); // Remove "Bearer " prefix

    if (!idToken) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'ID token is empty.',
      });
    }

    const decodedToken = await auth.verifyIdToken(idToken);

    // Attach the verified uid — downstream handlers MUST use this, not req.body/params
    req.uid = decodedToken.uid;
    req.decodedToken = decodedToken; // full token available if needed

    logger.debug(`Auth: verified uid=${req.uid}`);
    return next();
  } catch (err) {
    logger.warn(`Auth: token verification failed — ${err.message}`);

    // Map Firebase auth errors to appropriate HTTP responses
    if (
      err.code === 'auth/id-token-expired' ||
      err.code === 'auth/argument-error'
    ) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'ID token is expired or invalid. Please refresh and try again.',
      });
    }

    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Could not verify authentication token.',
    });
  }
}

module.exports = { verifyToken };
