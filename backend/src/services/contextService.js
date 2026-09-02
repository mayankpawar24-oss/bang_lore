'use strict';

/**
 * src/services/contextService.js
 * Higher-level service wrapping contextAgent with a simple in-memory cache.
 *
 * Cache behaviour:
 *   - TTL: 60 seconds per (patientId + messageType) key
 *   - Avoids hammering Firestore for back-to-back AI requests in the same session
 *   - Cache is cleared automatically after TTL; no external store needed
 *
 * Export:
 *   getPatientContext(patientId, messageType) → PatientContext
 */

const { buildPatientContext } = require('../agents/contextAgent');
const logger = require('../utils/logger');

// ---------------------------------------------------------------------------
// In-memory cache
// ---------------------------------------------------------------------------

const CACHE_TTL_MS = 60 * 1000; // 60 seconds

/** @type {Map<string, { data: object, expiresAt: number }>} */
const cache = new Map();

function getCacheKey(patientId, messageType) {
  return `${patientId}::${messageType || 'full'}`;
}

function getFromCache(key) {
  const entry = cache.get(key);
  if (!entry) return null;
  if (Date.now() > entry.expiresAt) {
    cache.delete(key);
    return null;
  }
  return entry.data;
}

function setInCache(key, data) {
  cache.set(key, { data, expiresAt: Date.now() + CACHE_TTL_MS });
}

/** Expose for testing / manual invalidation. */
function invalidateCache(patientId) {
  for (const key of cache.keys()) {
    if (key.startsWith(`${patientId}::`)) {
      cache.delete(key);
    }
  }
}

// ---------------------------------------------------------------------------
// Main export
// ---------------------------------------------------------------------------

/**
 * Get patient context, served from cache if available and fresh.
 *
 * @param {string} patientId   - Verified patient UID (must equal req.uid upstream).
 * @param {string} [messageType] - Context type filter passed to contextAgent.
 * @returns {Promise<object>} PatientContext object
 */
async function getPatientContext(patientId, messageType = 'full') {
  if (!patientId) throw new Error('getPatientContext: patientId is required.');

  const key = getCacheKey(patientId, messageType);
  const cached = getFromCache(key);

  if (cached) {
    logger.debug(`contextService: cache HIT for ${key}`);
    return cached;
  }

  logger.debug(`contextService: cache MISS for ${key}, fetching from Firestore`);
  const context = await buildPatientContext(patientId, messageType);
  setInCache(key, context);
  return context;
}

module.exports = { getPatientContext, invalidateCache };
