'use strict';

/**
 * src/routes/fhir.js
 * Express Router for FHIR export endpoints.
 *
 * Mounted at: /api/fhir
 * All routes require Firebase auth middleware.
 */

const { Router } = require('express');
const { verifyToken } = require('../middleware/auth');
const { exportFhir } = require('../controllers/fhirController');

const router = Router();

// All FHIR routes require auth
router.use(verifyToken);

/**
 * GET /api/fhir/export/:patientId
 * Patients may only export their own data (enforced in controller).
 */
router.get('/export/:patientId', exportFhir);

module.exports = router;
