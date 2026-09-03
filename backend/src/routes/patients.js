'use strict';

/**
 * src/routes/patients.js
 * Express Router for patient data endpoints.
 *
 * Mounted at: /api/patients
 * All routes require Firebase auth middleware.
 */

const { Router } = require('express');
const { verifyToken } = require('../middleware/auth');
const { getSummary } = require('../controllers/patientController');

const router = Router();

// All patient routes require auth
router.use(verifyToken);

/**
 * GET /api/patients/:patientId/summary
 * Accessible by approved doctors only.
 */
router.get('/:patientId/summary', getSummary);

module.exports = router;
