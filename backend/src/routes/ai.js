'use strict';

/**
 * src/routes/ai.js
 * Express Router for AI endpoints.
 *
 * Mounted at: /api/ai
 * All routes require: Firebase auth + AI rate limiter
 */

const { Router } = require('express');
const { verifyToken } = require('../middleware/auth');
const { aiRateLimiter } = require('../middleware/rateLimiter');
const { chat, submitSymptom } = require('../controllers/aiController');

const router = Router();

// All AI routes: auth first, then rate-limit
router.use(verifyToken, aiRateLimiter);

/**
 * POST /api/ai/chat
 * Body: { message: string, chatId?: string }
 */
router.post('/chat', chat);

/**
 * POST /api/ai/symptoms
 * Body: { description: string, severity: string, duration: string, associatedSymptoms?: string[] }
 */
router.post('/symptoms', submitSymptom);

module.exports = router;
