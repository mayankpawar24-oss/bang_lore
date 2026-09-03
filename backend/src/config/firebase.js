'use strict';

/**
 * src/config/firebase.js
 * Initialises Firebase Admin SDK exactly once.
 *
 * Credential resolution order:
 *  1. GOOGLE_APPLICATION_CREDENTIALS env-var (picked up automatically by SDK)
 *  2. FIREBASE_SERVICE_ACCOUNT_PATH env-var → loads the JSON file and uses
 *     admin.credential.cert()
 *
 * Exports: { admin, db, auth }
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
const logger = require('../utils/logger');

function initFirebase() {
  // If already initialised (e.g., in tests) skip re-init
  if (admin.apps.length > 0) {
    return admin.apps[0];
  }

  const projectId = process.env.FIREBASE_PROJECT_ID;

  // --- Strategy 1: GOOGLE_APPLICATION_CREDENTIALS (automatic) ---
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    logger.info('Firebase: using GOOGLE_APPLICATION_CREDENTIALS');
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId,
    });
    return admin.app();
  }

  // --- Strategy 2: FIREBASE_SERVICE_ACCOUNT_PATH ---
  const saPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (saPath) {
    const resolved = path.resolve(process.cwd(), saPath);
    if (!fs.existsSync(resolved)) {
      throw new Error(
        `Firebase service account file not found at: ${resolved}. ` +
          `Set FIREBASE_SERVICE_ACCOUNT_PATH or GOOGLE_APPLICATION_CREDENTIALS correctly.`
      );
    }
    // eslint-disable-next-line import/no-dynamic-require
    const serviceAccount = JSON.parse(fs.readFileSync(resolved, 'utf8'));
    logger.info(`Firebase: using service account from ${resolved}`);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
    });
    return admin.app();
  }

  throw new Error(
    'Firebase credentials not configured. ' +
      'Set GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_PATH.'
  );
}

// Initialise on first require
initFirebase();

const db = admin.firestore();
const auth = admin.auth();

// Use UTC timestamps in Firestore snapshots
db.settings({ ignoreUndefinedProperties: true });

module.exports = { admin, db, auth };
