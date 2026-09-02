'use strict';

/**
 * src/utils/aiProvider.js
 * Thin, provider-agnostic wrapper around AI chat-completion APIs.
 * Uses native fetch (Node >= 18) — no SDK dependencies required.
 *
 * Supported providers (set AI_PROVIDER env var):
 *   openai     → OpenAI Chat Completions API
 *   anthropic  → Anthropic Messages API
 *   google     → Google Gemini generateContent API
 *
 * Export:
 *   sendToAI(systemPrompt, userMessage, options?) → { content, provider }
 */

const logger = require('./logger');

// ---------------------------------------------------------------------------
// OpenAI
// ---------------------------------------------------------------------------
async function callOpenAI(systemPrompt, userMessage, options = {}) {
  const apiKey = process.env.OPENAI_API_KEY;
  const model = options.model || process.env.OPENAI_MODEL || 'gpt-4o-mini';
  const maxTokens = options.maxTokens || parseInt(process.env.MAX_TOKENS || '1024', 10);

  const body = {
    model,
    max_tokens: maxTokens,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userMessage },
    ],
    temperature: options.temperature ?? 0.3,
  };

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`OpenAI API error ${response.status}: ${errText}`);
  }

  const data = await response.json();
  const content = data.choices?.[0]?.message?.content?.trim() ?? '';
  return { content, provider: 'openai' };
}

// ---------------------------------------------------------------------------
// Anthropic
// ---------------------------------------------------------------------------
async function callAnthropic(systemPrompt, userMessage, options = {}) {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  const model = options.model || process.env.ANTHROPIC_MODEL || 'claude-3-haiku-20240307';
  const maxTokens = options.maxTokens || parseInt(process.env.MAX_TOKENS || '1024', 10);

  const body = {
    model,
    max_tokens: maxTokens,
    system: systemPrompt,
    messages: [{ role: 'user', content: userMessage }],
  };

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Anthropic API error ${response.status}: ${errText}`);
  }

  const data = await response.json();
  const content = data.content?.[0]?.text?.trim() ?? '';
  return { content, provider: 'anthropic' };
}

// ---------------------------------------------------------------------------
// Google Gemini
// ---------------------------------------------------------------------------
async function callGoogle(systemPrompt, userMessage, options = {}) {
  const apiKey = process.env.GOOGLE_AI_API_KEY;
  const model = options.model || process.env.GOOGLE_AI_MODEL || 'gemini-1.5-flash';
  const maxTokens = options.maxTokens || parseInt(process.env.MAX_TOKENS || '1024', 10);

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const body = {
    system_instruction: { parts: [{ text: systemPrompt }] },
    contents: [{ role: 'user', parts: [{ text: userMessage }] }],
    generationConfig: { maxOutputTokens: maxTokens, temperature: options.temperature ?? 0.3 },
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Google AI API error ${response.status}: ${errText}`);
  }

  const data = await response.json();
  const content =
    data.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? '';
  return { content, provider: 'google' };
}

// ---------------------------------------------------------------------------
// Local Mock Fallback when AI_PROVIDER is blank / disabled
// ---------------------------------------------------------------------------

function getLocalMockResponse(userMessage, systemPrompt) {
  const lower = (userMessage || '').toLowerCase();

  if (lower.includes('medicine') || lower.includes('medication') || lower.includes('dose')) {
    return 'Based on your health profile, your medications are scheduled as prescribed. Please check your schedule card for timing details and notify your care provider if you experience side effects.';
  }

  if (lower.includes('appointment') || lower.includes('doctor') || lower.includes('visit')) {
    return 'Your upcoming appointments are listed in your calendar tab. You can request a new consultation or reschedule existing appointments directly through the app.';
  }

  if (lower.includes('bp') || lower.includes('blood pressure') || lower.includes('heart') || lower.includes('vital')) {
    return 'Your vital signs are tracked continuously. Recent readings show stability. If you feel unwell or notice unusual changes, contact your care team immediately.';
  }

  if (lower.includes('dizzy') || lower.includes('pain') || lower.includes('fever') || lower.includes('symptom')) {
    return 'Thank you for reporting your symptoms. I have logged this entry in your health records. If symptoms persist or worsen, please consult your physician immediately.';
  }

  return 'I am your Continuum Health AI assistant. I have reviewed your request alongside your health context. For specific medical diagnosis, please consult your assigned physician.';
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Send a prompt to the configured AI provider.
 * If AI_PROVIDER is blank, returns a local fallback response.
 *
 * @param {string} systemPrompt - System / instruction context for the AI.
 * @param {string} userMessage  - The user's message / query.
 * @param {object} [options]    - Optional overrides: { model, maxTokens, temperature }
 * @returns {Promise<{ content: string, provider: string }>}
 */
async function sendToAI(systemPrompt, userMessage, options = {}) {
  const provider = (process.env.AI_PROVIDER || '').trim().toLowerCase();

  if (!provider) {
    logger.info('AI_PROVIDER is blank. Returning local mock response.');
    return {
      content: getLocalMockResponse(userMessage, systemPrompt),
      provider: 'none (local fallback)',
    };
  }

  try {
    switch (provider) {
      case 'openai':
        return await callOpenAI(systemPrompt, userMessage, options);
      case 'anthropic':
        return await callAnthropic(systemPrompt, userMessage, options);
      case 'google':
        return await callGoogle(systemPrompt, userMessage, options);
      default:
        logger.warn(`Unknown AI_PROVIDER "${provider}". Falling back to local response.`);
        return {
          content: getLocalMockResponse(userMessage, systemPrompt),
          provider: 'none (local fallback)',
        };
    }
  } catch (err) {
    logger.error(`AI provider (${provider}) call failed: ${err.message}`);
    throw err;
  }
}

module.exports = { sendToAI };
