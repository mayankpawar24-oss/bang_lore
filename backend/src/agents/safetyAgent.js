'use strict';

/**
 * src/agents/safetyAgent.js
 * Safety / risk agent. Evaluates both the user message and the AI's clinical
 * response for emergencies and inappropriate certainty claims.
 *
 * Export:
 *   checkSafety(clinicalResponse, userMessage)
 *     → { isSafe, emergencyDetected, emergencyMessage, safeResponse }
 */

const logger = require('../utils/logger');

// ---------------------------------------------------------------------------
// Emergency keyword sets
// ---------------------------------------------------------------------------

const EMERGENCY_PATTERNS = [
  // Cardiac
  /chest\s*pain/i,
  /heart\s*attack/i,
  /cardiac\s*arrest/i,
  // Respiratory
  /can'?t?\s*breathe/i,
  /difficulty\s*breath/i,
  /shortness\s*of\s*breath/i,
  /not\s*breathing/i,
  /stopped\s*breathing/i,
  // Neurological
  /stroke/i,
  /seizure/i,
  /unconscious/i,
  /unresponsive/i,
  /fainted/i,
  /passing\s*out/i,
  // Bleeding
  /severe\s*bleeding/i,
  /heavy\s*bleeding/i,
  /uncontrolled\s*bleeding/i,
  /internal\s*bleeding/i,
  // Other life threats
  /anaphylaxis/i,
  /allergic\s*reaction.*severe/i,
  /severe.*allergic\s*reaction/i,
  /overdose/i,
  /poisoning/i,
  /suicide/i,
  /suicidal/i,
  /self\s*harm/i,
  /choking/i,
  /drowning/i,
  /severe\s*pain/i,
  /911/i,
  /emergency/i,
];

/**
 * Patterns suggesting the AI is making overly definitive diagnoses.
 * These reduce trust and may be inappropriate.
 */
const CERTAINTY_PATTERNS = [
  /you\s+(definitely|certainly|absolutely)\s+have/i,
  /you\s+are\s+(definitely|certainly)\s+diagnosed/i,
  /this\s+is\s+(definitely|certainly)\s+a\s+diagnosis/i,
  /i\s+can\s+confirm\s+(that\s+)?you\s+have/i,
  /guaranteed\s+to\s+(be|have)/i,
];

const DISCLAIMER =
  'This information is for educational purposes only and does not constitute medical advice. ' +
  'Always consult a qualified healthcare professional before making any medical decisions.';

const EMERGENCY_RESPONSE = `🚨 **EMERGENCY DETECTED** 🚨

Based on your message, you may be experiencing a medical emergency.

**Call emergency services (911 or your local emergency number) IMMEDIATELY.**

Do not wait. Do not drive yourself. Call for help now.

Common emergency signs include:
- Chest pain or pressure
- Difficulty breathing
- Signs of stroke (face drooping, arm weakness, speech difficulty)
- Severe or uncontrolled bleeding
- Loss of consciousness

${DISCLAIMER}`;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function detectEmergency(text) {
  if (!text) return false;
  return EMERGENCY_PATTERNS.some((pattern) => pattern.test(text));
}

function detectInappropriateCertainty(text) {
  if (!text) return false;
  return CERTAINTY_PATTERNS.some((pattern) => pattern.test(text));
}

function appendDisclaimer(text) {
  // Avoid duplicate disclaimers
  if (text.includes(DISCLAIMER)) return text;
  return `${text}\n\n---\n*${DISCLAIMER}*`;
}

function sanitiseCertainty(text) {
  return text
    .replace(/you\s+(definitely|certainly|absolutely)\s+have/gi, 'you may have')
    .replace(/i\s+can\s+confirm\s+(that\s+)?you\s+have/gi, 'it is possible that you have')
    .replace(/guaranteed\s+to\s+(be|have)/gi, 'may');
}

// ---------------------------------------------------------------------------
// Main export
// ---------------------------------------------------------------------------

/**
 * Evaluate a clinical AI response for safety issues.
 *
 * @param {string} clinicalResponse - The reasoning string from clinicalAgent.
 * @param {string} userMessage      - The original user message.
 * @returns {{
 *   isSafe: boolean,
 *   emergencyDetected: boolean,
 *   emergencyMessage: string|null,
 *   safeResponse: string
 * }}
 */
function checkSafety(clinicalResponse, userMessage) {
  const emergencyInMessage = detectEmergency(userMessage);
  const emergencyInResponse = detectEmergency(clinicalResponse);
  const emergencyDetected = emergencyInMessage || emergencyInResponse;

  logger.debug(
    `safetyAgent: emergencyDetected=${emergencyDetected}, ` +
      `certaintyViolation=${detectInappropriateCertainty(clinicalResponse)}`
  );

  if (emergencyDetected) {
    return {
      isSafe: false,
      emergencyDetected: true,
      emergencyMessage: EMERGENCY_RESPONSE,
      safeResponse: EMERGENCY_RESPONSE,
    };
  }

  // Sanitise certainty language and add disclaimer
  let safeResponse = clinicalResponse;

  if (detectInappropriateCertainty(safeResponse)) {
    safeResponse = sanitiseCertainty(safeResponse);
    logger.debug('safetyAgent: certainty language sanitised');
  }

  safeResponse = appendDisclaimer(safeResponse);

  return {
    isSafe: true,
    emergencyDetected: false,
    emergencyMessage: null,
    safeResponse,
  };
}

module.exports = { checkSafety };
