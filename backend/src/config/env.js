'use strict';

/**
 * src/config/env.js
 * Validates all required environment variables at startup.
 */

const REQUIRED_ALWAYS = ['FIREBASE_PROJECT_ID'];

/**
 * Map of AI_PROVIDER -> the API key env-var name that must be present.
 */
const AI_PROVIDER_KEY_MAP = {
  openai: 'OPENAI_API_KEY',
  anthropic: 'ANTHROPIC_API_KEY',
  google: 'GOOGLE_AI_API_KEY',
};

const SUPPORTED_PROVIDERS = Object.keys(AI_PROVIDER_KEY_MAP);

function validateEnv() {
  const missing = [];

  // Always-required vars
  for (const key of REQUIRED_ALWAYS) {
    if (!process.env[key]) missing.push(key);
  }

  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missing.join(', ')}. ` +
        `Copy .env.example to .env and fill in the values.`
    );
  }

  // AI provider validation (AI is OPTIONAL)
  const provider = (process.env.AI_PROVIDER || '').trim().toLowerCase();
  if (provider) {
    if (!SUPPORTED_PROVIDERS.includes(provider)) {
      throw new Error(
        `Invalid AI_PROVIDER "${process.env.AI_PROVIDER}". ` +
          `Supported values when AI is enabled: ${SUPPORTED_PROVIDERS.join(', ')}.`
      );
    }
    const requiredKey = AI_PROVIDER_KEY_MAP[provider];
    if (!process.env[requiredKey] || !process.env[requiredKey].trim()) {
      throw new Error(
        `AI_PROVIDER is set to "${provider}" but the required env var ` +
          `"${requiredKey}" is missing or empty. ` +
          `Please add it to your .env file.`
      );
    }
  }

  // Normalise provider to lowercase (or empty string if disabled)
  process.env.AI_PROVIDER = provider;
}

module.exports = { validateEnv };
