'use strict';

/**
 * src/agents/contextAgent.js
 * Fetches and structures patient data from Firestore for use in AI prompts.
 *
 * Security: This agent ONLY fetches data for the provided patientId.
 * Callers must guarantee that patientId is the verified req.uid from the
 * Firebase auth middleware — never from client-supplied body/params.
 *
 * Export:
 *   buildPatientContext(patientId, requestType?) → PatientContext object
 */

const { db } = require('../config/firebase');
const logger = require('../utils/logger');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Safely convert Firestore Timestamp to ISO string. */
function toISO(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return String(value);
}

/** Fetch a Firestore document; return data or null. */
async function fetchDoc(docRef) {
  const snap = await docRef.get();
  return snap.exists ? { id: snap.id, ...snap.data() } : null;
}

/** Fetch a sub-collection ordered by a field, limited to N docs. */
async function fetchCollection(collRef, orderField, direction, limit) {
  let query = collRef;
  if (orderField) query = query.orderBy(orderField, direction || 'desc');
  if (limit) query = query.limit(limit);
  const snap = await query.get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

// ---------------------------------------------------------------------------
// Fetchers per request type
// ---------------------------------------------------------------------------

async function fetchProfile(patientId) {
  const doc = await fetchDoc(db.collection('patients').doc(patientId));
  if (!doc) throw new Error(`Patient ${patientId} not found in Firestore.`);
  return {
    name: doc.name || 'Unknown',
    age: doc.age ?? null,
    conditions: doc.conditions || [],
    bloodGroup: doc.bloodGroup || null,
    status: doc.status || null,
  };
}

async function fetchRecentVitals(patientId, limit = 10) {
  const col = db
    .collection('patients')
    .doc(patientId)
    .collection('vitals');
  const docs = await fetchCollection(col, 'recordedAt', 'desc', limit);
  return docs.map((v) => ({
    id: v.id,
    heartRate: v.heartRate ?? null,
    systolic: v.systolic ?? null,
    diastolic: v.diastolic ?? null,
    spo2: v.spo2 ?? null,
    weight: v.weight ?? null,
    recordedAt: toISO(v.recordedAt),
  }));
}

async function fetchMedications(patientId) {
  const col = db
    .collection('patients')
    .doc(patientId)
    .collection('medications');
  const docs = await fetchCollection(col, null, null, 20);
  return docs
    .filter((m) => m.active !== false) // active medications only
    .map((m) => ({
      id: m.id,
      name: m.name,
      dosage: m.dosage,
      frequency: m.frequency,
      times: m.times || [],
      isTaken: m.isTaken ?? false,
    }));
}

async function fetchUpcomingAppointments(patientId, limit = 3) {
  const col = db
    .collection('patients')
    .doc(patientId)
    .collection('appointments');
  // Fetch next scheduled appointments
  const docs = await fetchCollection(col, 'dateTime', 'asc', limit);
  return docs.map((a) => ({
    id: a.id,
    doctorName: a.doctorName,
    dateTime: toISO(a.dateTime),
    status: a.status,
    notes: a.notes || null,
  }));
}

async function fetchFamilyHistory(patientId) {
  const col = db
    .collection('patients')
    .doc(patientId)
    .collection('familyMembers');
  const docs = await fetchCollection(col, null, null, 15);
  return docs.map((f) => ({
    id: f.id,
    name: f.name,
    relationship: f.relationship,
    generation: f.generation,
    knownConditions: f.knownConditions || [],
    familyHistory: f.familyHistory || [],
    careNeeds: f.careNeeds || null,
    careTasks: f.careTasks || [],
    hydration: f.hydration || null,
    walking: f.walking || null,
    medication: f.medication || null,
  }));
}

async function fetchRecentSymptoms(patientId, limit = 5) {
  const col = db
    .collection('patients')
    .doc(patientId)
    .collection('symptoms');
  const docs = await fetchCollection(col, 'timestamp', 'desc', limit);
  return docs.map((s) => ({
    id: s.id,
    description: s.description,
    severity: s.severity,
    duration: s.duration,
    timestamp: toISO(s.timestamp),
    riskLevel: s.riskLevel || null,
  }));
}

// ---------------------------------------------------------------------------
// Main export
// ---------------------------------------------------------------------------

/**
 * Build a structured patient context object for use in AI prompts.
 *
 * @param {string} patientId   - The verified patient UID (must equal req.uid).
 * @param {string} [requestType] - Optional filter:
 *    'medication' | 'vitals' | 'appointments' | 'symptoms' | 'full' (default)
 * @returns {Promise<PatientContext>}
 */
async function buildPatientContext(patientId, requestType = 'full') {
  if (!patientId) throw new Error('patientId is required in buildPatientContext');

  logger.debug(`contextAgent: building context for ${patientId}, type=${requestType}`);

  // Profile is always fetched
  const profile = await fetchProfile(patientId);

  // Selective fetching based on requestType
  const isFull = requestType === 'full';

  const [recentVitals, medications, upcomingAppointments, familyHistory, recentSymptoms] =
    await Promise.all([
      isFull || requestType === 'vitals' ? fetchRecentVitals(patientId) : Promise.resolve([]),
      isFull || requestType === 'medication' ? fetchMedications(patientId) : Promise.resolve([]),
      isFull || requestType === 'appointments'
        ? fetchUpcomingAppointments(patientId)
        : Promise.resolve([]),
      isFull || requestType === 'family' ? fetchFamilyHistory(patientId) : Promise.resolve([]),
      isFull || requestType === 'symptoms' ? fetchRecentSymptoms(patientId) : Promise.resolve([]),
    ]);

  return {
    patientId, // included for audit; never sent to AI directly
    profile,
    recentVitals,
    medications,
    upcomingAppointments,
    familyHistory,
    recentSymptoms,
  };
}

module.exports = { buildPatientContext };
