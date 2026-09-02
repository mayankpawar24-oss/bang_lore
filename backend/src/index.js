'use strict';

/**
 * src/index.js
 * Main Express application entry point for Continuum Health Backend.
 *
 * Startup order:
 *   1. Load .env
 *   2. Validate env vars
 *   3. Initialise Firebase Admin SDK
 *   4. Configure Express middleware (helmet, cors, rate-limit, body-parser)
 *   5. Register routes
 *   6. Global error handler
 *   7. Start HTTP server
 */

// --- 1. Load environment variables first ---
require('dotenv').config();

// --- 2. Validate environment ---
const { validateEnv } = require('./config/env');
try {
  validateEnv();
} catch (err) {
  // eslint-disable-next-line no-console
  console.error(`[STARTUP ERROR] ${err.message}`);
  process.exit(1);
}

// --- 3. Initialise Firebase (throws on misconfiguration) ---
require('./config/firebase');

// --- Now safe to import modules that depend on firebase/env ---
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');

const logger = require('./utils/logger');
const { generalRateLimiter } = require('./middleware/rateLimiter');

const aiRoutes = require('./routes/ai');
const patientRoutes = require('./routes/patients');
const fhirRoutes = require('./routes/fhir');

// ---------------------------------------------------------------------------
// App setup
// ---------------------------------------------------------------------------

const app = express();

// --- Security headers ---
app.use(helmet());

// --- CORS ---
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

app.use(
  cors({
    origin: (origin, callback) => {
      // Allow requests with no origin (e.g. mobile apps, curl)
      if (!origin) return callback(null, true);
      if (allowedOrigins.includes(origin)) return callback(null, true);
      logger.warn(`CORS blocked origin: ${origin}`);
      return callback(new Error(`CORS: origin ${origin} not allowed`), false);
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  })
);

// --- Body parsing ---
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: false }));

// --- General rate limiter (applied before routes) ---
app.use(generalRateLimiter);

// ---------------------------------------------------------------------------
// Health check
// ---------------------------------------------------------------------------

app.get('/health', async (req, res) => {
  const { admin, db } = require('./config/firebase');

  const firebaseAdmin = Boolean(admin && admin.apps && admin.apps.length > 0);
  let firestoreConnected = false;
  try {
    if (firebaseAdmin) {
      await db.collection('_healthcheck').doc('ping').get();
      firestoreConnected = true;
    }
  } catch (_) {
    firestoreConnected = false;
  }

  const rawProvider = (process.env.AI_PROVIDER || '').trim().toLowerCase();
  const aiEnabled = Boolean(rawProvider);
  const aiProvider = aiEnabled ? rawProvider : 'none';

  res.status(200).json({
    status: 'ok',
    service: 'continuum-health-backend',
    timestamp: new Date().toISOString(),
    firebaseAdmin,
    firestoreConnected,
    aiEnabled,
    aiProvider,
  });
});

// ---------------------------------------------------------------------------
// API Routes
// ---------------------------------------------------------------------------

app.use('/api/ai', aiRoutes);
app.use('/api/patients', patientRoutes);
app.use('/api/fhir', fhirRoutes);

// 404 fallthrough handler
app.use((req, res) => {
  res.status(404).json({
    error: 'NotFound',
    message: `Route ${req.method} ${req.path} not found.`,
  });
});

// ---------------------------------------------------------------------------
// Global error handler
// ---------------------------------------------------------------------------

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  // CORS errors
  if (err.message && err.message.startsWith('CORS:')) {
    return res.status(403).json({ error: 'Forbidden', message: err.message });
  }

  logger.error(`Unhandled error: ${err.message}`, {
    method: req.method,
    path: req.path,
    stack: err.stack,
  });

  const statusCode = err.status || err.statusCode || 500;
  return res.status(statusCode).json({
    error: 'InternalServerError',
    message:
      process.env.NODE_ENV === 'production'
        ? 'An unexpected error occurred.'
        : err.message,
  });
});

// ---------------------------------------------------------------------------
// Start server
// ---------------------------------------------------------------------------

if (require.main === module) {
  const PORT = parseInt(process.env.PORT || '3000', 10);
  app.listen(PORT, () => {
    logger.info(`Continuum Health Backend running on port ${PORT} [${process.env.NODE_ENV}]`);
    logger.info(`AI Provider: ${process.env.AI_PROVIDER || 'none (disabled)'}`);
    logger.info(`Health check: http://localhost:${PORT}/health`);
  });
}

module.exports = app; // exported for supertest in tests
