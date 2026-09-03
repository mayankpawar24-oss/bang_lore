'use strict';

/**
 * src/controllers/aiController.js
 * Handles all AI-powered endpoints:
 *   POST /api/ai/chat     — chat(req, res)
 *   POST /api/ai/symptoms — submitSymptom(req, res)
 *
 * Security: req.uid (set by auth middleware) is the authoritative patientId.
 * Body/params are NEVER used to determine which patient's data to access.
 */

const { v4: uuidv4 } = require('uuid');
const { db } = require('../config/firebase');
const { getPatientContext } = require('../services/contextService');
const { clinicalReason } = require('../agents/clinicalAgent');
const { checkSafety } = require('../agents/safetyAgent');
const { generateFinalResponse } = require('../agents/sentinelAgent');
const { sendToAI } = require('../utils/aiProvider');
const logger = require('../utils/logger');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function now() {
  return new Date();
}

/**
 * Save a message pair (user + assistant) to Firestore chat sub-collection.
 */
async function saveChatMessages(patientId, chatId, userMessage, assistantContent) {
  const chatRef = db
    .collection('patients')
    .doc(patientId)
    .collection('aiChats')
    .doc(chatId);

  // Ensure the chat document exists
  await chatRef.set({ createdAt: now(), patientId }, { merge: true });

  const messagesRef = chatRef.collection('messages');
  const batch = db.batch();

  batch.set(messagesRef.doc(uuidv4()), {
    sender: 'user',
    content: userMessage,
    timestamp: now(),
  });

  batch.set(messagesRef.doc(uuidv4()), {
    sender: 'assistant',
    content: assistantContent,
    timestamp: now(),
  });

  await batch.commit();
}

// ---------------------------------------------------------------------------
// Controllers
// ---------------------------------------------------------------------------

/**
 * POST /api/ai/chat
 * Body: { message: string, chatId?: string }
 */
async function chat(req, res) {
  try {
    const patientId = req.uid; // always from verified token
    const { message, chatId: existingChatId } = req.body;

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return res.status(400).json({ error: 'BadRequest', message: '"message" is required.' });
    }

    const trimmedMessage = message.trim();
    const chatId = existingChatId || uuidv4();

    logger.info(`aiController.chat: patientId=${patientId}, chatId=${chatId}`);

    // --- Pipeline: context → clinical → safety → sentinel ---
    const patientContext = await getPatientContext(patientId, 'full');
    const clinicalResponse = await clinicalReason(patientContext, trimmedMessage);
    const safetyResult = checkSafety(clinicalResponse.reasoning, trimmedMessage);
    const finalResponse = generateFinalResponse(clinicalResponse, safetyResult, patientContext);

    // Persist to Firestore (non-blocking error — don't fail the response)
    saveChatMessages(patientId, chatId, trimmedMessage, finalResponse.answer).catch((err) =>
      logger.error(`aiController.chat: failed to save messages — ${err.message}`)
    );

    return res.status(200).json({
      chatId,
      answer: finalResponse.answer,
      confidence: finalResponse.confidence,
      recommendedAction: finalResponse.recommendedAction,
      safetyNote: finalResponse.safetyNote,
    });
  } catch (err) {
    logger.error(`aiController.chat error: ${err.message}`, { stack: err.stack });
    return res.status(500).json({
      error: 'InternalServerError',
      message: 'An error occurred while processing your request. Please try again.',
    });
  }
}

// ---------------------------------------------------------------------------
// Risk level helper
// ---------------------------------------------------------------------------

function deriveRiskLevel(analysisText, severity) {
  const lower = (analysisText || '').toLowerCase();
  if (
    lower.includes('emergency') ||
    lower.includes('urgent') ||
    lower.includes('immediately') ||
    severity === 'severe'
  ) {
    return 'high';
  }
  if (lower.includes('moderate') || lower.includes('monitor') || severity === 'moderate') {
    return 'medium';
  }
  return 'low';
}

/**
 * POST /api/ai/symptoms
 * Body: { description: string, severity: string, duration: string, associatedSymptoms?: string[] }
 */
async function submitSymptom(req, res) {
  try {
    const patientId = req.uid;
    const { description, severity, duration, associatedSymptoms = [] } = req.body;

    if (!description || typeof description !== 'string') {
      return res.status(400).json({ error: 'BadRequest', message: '"description" is required.' });
    }

    logger.info(`aiController.submitSymptom: patientId=${patientId}`);

    const patientContext = await getPatientContext(patientId, 'symptoms');

    const systemPrompt = `You are a clinical triage assistant. Analyse the reported symptom(s) and provide:
1. A brief clinical assessment.
2. Possible causes (not a diagnosis).
3. A recommended action: emergency | see_doctor | self_care | monitor.
Keep the response under 250 words. Be empathetic and clear.`;

    const userMessage = [
      `Symptom: ${description}`,
      `Severity: ${severity || 'not specified'}`,
      `Duration: ${duration || 'not specified'}`,
      associatedSymptoms.length
        ? `Associated symptoms: ${associatedSymptoms.join(', ')}`
        : null,
      `Patient age: ${patientContext.profile.age ?? 'unknown'}`,
      patientContext.profile.conditions?.length
        ? `Known conditions: ${patientContext.profile.conditions.join(', ')}`
        : null,
    ]
      .filter(Boolean)
      .join('\n');

    const { content: rawAnalysis } = await sendToAI(systemPrompt, userMessage);

    // Safety check on symptom analysis
    const safetyResult = checkSafety(rawAnalysis, description);
    const analysis = safetyResult.safeResponse;
    const riskLevel = deriveRiskLevel(rawAnalysis, severity);

    // Determine recommended action
    let recommendedAction = 'monitor';
    const lowerAnalysis = rawAnalysis.toLowerCase();
    if (safetyResult.emergencyDetected || lowerAnalysis.includes('emergency')) {
      recommendedAction = 'emergency';
    } else if (lowerAnalysis.includes('see_doctor') || lowerAnalysis.includes('see a doctor')) {
      recommendedAction = 'see_doctor';
    } else if (lowerAnalysis.includes('self_care') || lowerAnalysis.includes('self-care')) {
      recommendedAction = 'self_care';
    }

    // Save symptom to Firestore
    const symptomId = uuidv4();
    const symptomRef = db
      .collection('patients')
      .doc(patientId)
      .collection('symptoms')
      .doc(symptomId);

    await symptomRef.set({
      description,
      severity: severity || null,
      duration: duration || null,
      associatedSymptoms,
      timestamp: now(),
      aiResponse: analysis,
      riskLevel,
      sharedWithDoctor: false,
    });

    return res.status(201).json({
      symptomId,
      analysis,
      riskLevel,
      recommendedAction,
    });
  } catch (err) {
    logger.error(`aiController.submitSymptom error: ${err.message}`, { stack: err.stack });
    return res.status(500).json({
      error: 'InternalServerError',
      message: 'An error occurred while analysing your symptom. Please try again.',
    });
  }
}

module.exports = { chat, submitSymptom };
