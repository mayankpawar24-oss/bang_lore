'use strict';

/**
 * src/agents/sentinelAgent.js
 * Sentinel / gating agent. The last stage in the AI pipeline.
 * Assembles the final structured response that is sent to the client.
 *
 * Pipeline: context → clinical → safety → sentinel (this file)
 *
 * Export:
 *   generateFinalResponse(clinicalResponse, safetyResult, patientContext)
 *     → { answer, confidence, recommendedAction, safetyNote }
 */

const logger = require('../utils/logger');

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const SAFETY_NOTE =
  'This response is for informational purposes only. It does not replace advice ' +
  'from your healthcare provider. Always consult your doctor for medical decisions.';

const EMERGENCY_SAFETY_NOTE =
  '⚠️ This response indicates a potential emergency. ' +
  'Please contact emergency services (911) or your nearest emergency room immediately.';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Determine the recommended action based on confidence level and emergency status.
 * @returns {'emergency'|'see_doctor'|'self_care'|null}
 */
function determineRecommendedAction(confidenceLevel, emergencyDetected, safeResponse) {
  if (emergencyDetected) return 'emergency';

  // Look for hints in the safe response text
  const lowerResp = (safeResponse || '').toLowerCase();
  if (
    lowerResp.includes('see a doctor') ||
    lowerResp.includes('consult your doctor') ||
    lowerResp.includes('medical attention') ||
    lowerResp.includes('healthcare provider') ||
    confidenceLevel === 'low'
  ) {
    return 'see_doctor';
  }

  if (
    lowerResp.includes('rest') ||
    lowerResp.includes('hydrat') ||
    lowerResp.includes('over-the-counter') ||
    lowerResp.includes('home remedy') ||
    lowerResp.includes('self-care')
  ) {
    return 'self_care';
  }

  return null;
}

/**
 * Strip internal chain-of-thought markers and clean up the response.
 */
function cleanAnswer(text) {
  if (!text) return '';

  return text
    // Remove markdown-style internal reasoning blocks
    .replace(/<think>[\s\S]*?<\/think>/gi, '')
    .replace(/\[internal reasoning\][\s\S]*?\[\/internal reasoning\]/gi, '')
    // Remove leading/trailing blank lines
    .trim();
}

// ---------------------------------------------------------------------------
// Main export
// ---------------------------------------------------------------------------

/**
 * Generate the final gated response to send to the client.
 *
 * @param {{ reasoning: string, confidenceLevel: string }} clinicalResponse
 * @param {{ isSafe: boolean, emergencyDetected: boolean, emergencyMessage: string|null, safeResponse: string }} safetyResult
 * @param {object} patientContext - From contextAgent (used for logging only here)
 * @returns {{
 *   answer: string,
 *   confidence: 'low'|'medium'|'high',
 *   recommendedAction: 'emergency'|'see_doctor'|'self_care'|null,
 *   safetyNote: string
 * }}
 */
function generateFinalResponse(clinicalResponse, safetyResult, patientContext) {
  const patientId = patientContext?.patientId || 'unknown';
  logger.debug(`sentinelAgent: generating final response for patient ${patientId}`);

  // If emergency detected — bypass everything and return emergency response immediately
  if (safetyResult.emergencyDetected) {
    logger.warn(`sentinelAgent: EMERGENCY flagged for patient ${patientId}`);
    return {
      answer: safetyResult.emergencyMessage,
      confidence: 'high',
      recommendedAction: 'emergency',
      safetyNote: EMERGENCY_SAFETY_NOTE,
    };
  }

  // Normal path: clean and format the safe response
  const rawAnswer = safetyResult.safeResponse || clinicalResponse.reasoning || '';
  const answer = cleanAnswer(rawAnswer);
  const confidence = clinicalResponse.confidenceLevel || 'medium';

  const recommendedAction = determineRecommendedAction(
    confidence,
    safetyResult.emergencyDetected,
    rawAnswer
  );

  logger.debug(
    `sentinelAgent: confidence=${confidence}, recommendedAction=${recommendedAction}`
  );

  return {
    answer,
    confidence,
    recommendedAction,
    safetyNote: SAFETY_NOTE,
  };
}

module.exports = { generateFinalResponse };
