'use strict';

/**
 * src/agents/clinicalAgent.js
 * Clinical reasoning agent. Takes a structured patient context and the user's
 * message and produces a medically-grounded reasoning response using the
 * configured AI provider.
 *
 * Export:
 *   clinicalReason(patientContext, userMessage) → { reasoning, confidenceLevel }
 */

const { sendToAI } = require('../utils/aiProvider');
const logger = require('../utils/logger');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Format the patient context into a readable text block for the system prompt. */
function formatContextForPrompt(ctx) {
  const lines = [];

  lines.push(`Patient: ${ctx.profile.name}, Age: ${ctx.profile.age ?? 'Unknown'}`);

  if (ctx.profile.conditions?.length) {
    lines.push(`Known conditions: ${ctx.profile.conditions.join(', ')}`);
  }
  if (ctx.profile.bloodGroup) {
    lines.push(`Blood group: ${ctx.profile.bloodGroup}`);
  }

  // Latest vitals
  if (ctx.recentVitals?.length) {
    const v = ctx.recentVitals[0];
    lines.push(
      `Latest vitals (${v.recordedAt}): HR=${v.heartRate ?? 'N/A'} bpm, ` +
        `BP=${v.systolic ?? 'N/A'}/${v.diastolic ?? 'N/A'} mmHg, ` +
        `SpO2=${v.spo2 ?? 'N/A'}%, Weight=${v.weight ?? 'N/A'} kg`
    );
  }

  // Active medications
  if (ctx.medications?.length) {
    const meds = ctx.medications.map((m) => `${m.name} ${m.dosage} (${m.frequency})`);
    lines.push(`Active medications: ${meds.join('; ')}`);
  }

  // Upcoming appointments
  if (ctx.upcomingAppointments?.length) {
    const appt = ctx.upcomingAppointments[0];
    lines.push(`Next appointment: ${appt.doctorName} on ${appt.dateTime}`);
  }

  // Family history & tree context
  if (ctx.familyHistory?.length) {
    const familyMembers = ctx.familyHistory.map((f) => {
      const parts = [`${f.name} (${f.relationship}, Gen ${f.generation})`];
      if (f.knownConditions?.length) parts.push(`Conditions: ${f.knownConditions.join(', ')}`);
      if (f.hydration) parts.push(`Hydration: ${f.hydration}`);
      if (f.walking) parts.push(`Walking: ${f.walking}`);
      if (f.medication) parts.push(`Medication status: ${f.medication}`);
      if (f.careNeeds) parts.push(`Care needs: ${f.careNeeds}`);
      return parts.join(' | ');
    });
    lines.push(`Family tree & care context:\n- ${familyMembers.join('\n- ')}`);
  }

  // Recent symptoms
  if (ctx.recentSymptoms?.length) {
    const symptoms = ctx.recentSymptoms
      .map((s) => `${s.description} (severity: ${s.severity}, ${s.duration})`)
      .slice(0, 3);
    lines.push(`Recent symptoms: ${symptoms.join('; ')}`);
  }

  return lines.join('\n');
}

function buildSystemPrompt(patientContext) {
  const contextBlock = formatContextForPrompt(patientContext);

  return `You are a clinical reasoning assistant supporting a healthcare application.
You are NOT a substitute for a licensed physician and must NEVER make a definitive diagnosis.
Your role is to analyse the patient's message in the context of their medical history and provide
thoughtful, evidence-based reasoning to help them understand their health situation.

## Patient Context
${contextBlock}

## Instructions
- Reason carefully based on the patient context above.
- Acknowledge uncertainty where appropriate.
- Use plain, empathetic language the patient can understand.
- Do NOT claim to diagnose conditions definitively.
- If you detect possible emergencies, flag them clearly.
- Keep your response focused and concise (under 300 words).
- End with a confidence indicator: [CONFIDENCE: low|medium|high]`;
}

// ---------------------------------------------------------------------------
// Confidence extractor
// ---------------------------------------------------------------------------

function extractConfidence(text) {
  const match = text.match(/\[CONFIDENCE:\s*(low|medium|high)\]/i);
  return match ? match[1].toLowerCase() : 'medium';
}

function stripConfidenceTag(text) {
  return text.replace(/\[CONFIDENCE:\s*(low|medium|high)\]/gi, '').trim();
}

// ---------------------------------------------------------------------------
// Main export
// ---------------------------------------------------------------------------

/**
 * Run clinical reasoning on a user message given patient context.
 *
 * @param {object} patientContext - Output of contextAgent.buildPatientContext()
 * @param {string} userMessage    - The patient's question or message
 * @returns {Promise<{ reasoning: string, confidenceLevel: 'low'|'medium'|'high' }>}
 */
async function clinicalReason(patientContext, userMessage) {
  if (!patientContext || !userMessage) {
    throw new Error('clinicalReason: patientContext and userMessage are required.');
  }

  logger.debug(`clinicalAgent: reasoning for patient ${patientContext.patientId}`);

  const systemPrompt = buildSystemPrompt(patientContext);

  const { content } = await sendToAI(systemPrompt, userMessage);

  const confidenceLevel = extractConfidence(content);
  const reasoning = stripConfidenceTag(content);

  logger.debug(`clinicalAgent: confidence=${confidenceLevel}`);

  return { reasoning, confidenceLevel };
}

module.exports = { clinicalReason };
