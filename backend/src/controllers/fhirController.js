'use strict';

/**
 * src/controllers/fhirController.js
 * FHIR R4 data export endpoint.
 *
 *   GET /api/fhir/export/:patientId — exportFhir(req, res)
 *
 * Security: Only the patient themselves can export their own FHIR data.
 * req.uid (from verified Firebase token) must exactly match patientId param.
 */

const { generateFhirBundle } = require('../services/fhirService');
const logger = require('../utils/logger');

/**
 * GET /api/fhir/export/:patientId
 */
async function exportFhir(req, res) {
  try {
    const requestingUid = req.uid;
    const { patientId } = req.params;

    // Strict ownership check — patients can only export their own data
    if (requestingUid !== patientId) {
      logger.warn(
        `fhirController.exportFhir: uid=${requestingUid} tried to export patientId=${patientId}`
      );
      return res.status(403).json({
        error: 'Forbidden',
        message: 'You may only export your own FHIR records.',
      });
    }

    logger.info(`fhirController.exportFhir: generating bundle for patientId=${patientId}`);

    const bundle = await generateFhirBundle(patientId);

    // FHIR content-type as per spec
    return res.status(200)
      .setHeader('Content-Type', 'application/fhir+json')
      .json(bundle);
  } catch (err) {
    if (err.message.includes('not found')) {
      return res.status(404).json({ error: 'NotFound', message: err.message });
    }
    logger.error(`fhirController.exportFhir error: ${err.message}`, { stack: err.stack });
    return res.status(500).json({
      error: 'InternalServerError',
      message: 'Could not generate FHIR bundle.',
    });
  }
}

module.exports = { exportFhir };
