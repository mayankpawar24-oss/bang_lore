'use strict';

/**
 * src/controllers/patientController.js
 * Patient data endpoints for doctor access.
 *
 *   GET /api/patients/:patientId/summary — getSummary(req, res)
 *
 * Access control:
 *   - req.uid must be an APPROVED doctor for the requested patientId.
 *   - Approved permission is looked up in accessPermissions/{uid}_{patientId}.
 *   - Only fields listed in the permissions array are returned.
 *   - Patients accessing their own data should use the AI or FHIR endpoints.
 */

const { db } = require('../config/firebase');
const logger = require('../utils/logger');

// ---------------------------------------------------------------------------
// Field sets per permission name
// ---------------------------------------------------------------------------

const FIELD_SETS = {
  vitals: ['recentVitals'],
  medications: ['medications'],
  appointments: ['appointments'],
  medicalHistory: ['medicalHistory'],
  profile: ['profile'],
  familyHistory: ['familyHistory'],
  symptoms: ['symptoms'],
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function toISO(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  return String(value);
}

async function fetchSubCollection(patientId, collName, limit = 10) {
  const snap = await db
    .collection('patients')
    .doc(patientId)
    .collection(collName)
    .orderBy('recordedAt', 'desc')
    .limit(limit)
    .get()
    .catch(() =>
      // Some collections don't have recordedAt — fall back to unordered
      db.collection('patients').doc(patientId).collection(collName).limit(limit).get()
    );
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

/**
 * Check whether the requesting doctor (uid) has approved access to patientId.
 * Returns the permissions array on success, null if no approved permission.
 */
async function resolvePermission(doctorId, patientId) {
  const permId = `${doctorId}_${patientId}`;
  const snap = await db.collection('accessPermissions').doc(permId).get();

  if (!snap.exists) return null;

  const data = snap.data();
  if (data.status !== 'approved') return null;

  return data.permissions || [];
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/**
 * GET /api/patients/:patientId/summary
 */
async function getSummary(req, res) {
  try {
    const doctorId = req.uid;
    const { patientId } = req.params;

    if (!patientId) {
      return res.status(400).json({ error: 'BadRequest', message: 'patientId param is required.' });
    }

    logger.info(`patientController.getSummary: doctorId=${doctorId}, patientId=${patientId}`);

    // --- Access control ---
    const permissions = await resolvePermission(doctorId, patientId);
    if (!permissions) {
      logger.warn(
        `patientController.getSummary: DENIED doctorId=${doctorId} for patientId=${patientId}`
      );
      return res.status(403).json({
        error: 'Forbidden',
        message: 'You do not have approved access to this patient\'s records.',
      });
    }

    // --- Fetch patient profile ---
    const profileSnap = await db.collection('patients').doc(patientId).get();
    if (!profileSnap.exists) {
      return res.status(404).json({ error: 'NotFound', message: 'Patient not found.' });
    }
    const profileData = profileSnap.data();

    // --- Assemble allowed fields only ---
    const summary = {};

    // Determine which high-level field sets are allowed
    const allowedFields = new Set(
      permissions.flatMap((p) => FIELD_SETS[p] || [])
    );

    // Always include minimal safe profile info
    summary.patientId = patientId;
    summary.name = profileData.name || 'Unknown';

    if (allowedFields.has('profile')) {
      summary.profile = {
        age: profileData.age ?? null,
        status: profileData.status || null,
        conditions: profileData.conditions || [],
        bloodGroup: profileData.bloodGroup || null,
      };
    }

    // Fetch sub-collections only for permitted fields
    const fetchTasks = [];

    if (allowedFields.has('recentVitals')) {
      fetchTasks.push(
        fetchSubCollection(patientId, 'vitals', 5).then((docs) => {
          summary.recentVitals = docs.map((v) => ({
            heartRate: v.heartRate,
            systolic: v.systolic,
            diastolic: v.diastolic,
            spo2: v.spo2,
            weight: v.weight,
            recordedAt: toISO(v.recordedAt),
          }));
        })
      );
    }

    if (allowedFields.has('medications')) {
      fetchTasks.push(
        fetchSubCollection(patientId, 'medications', 10).then((docs) => {
          summary.medications = docs
            .filter((m) => m.active !== false)
            .map((m) => ({
              name: m.name,
              dosage: m.dosage,
              frequency: m.frequency,
            }));
        })
      );
    }

    if (allowedFields.has('appointments')) {
      fetchTasks.push(
        fetchSubCollection(patientId, 'appointments', 5).then((docs) => {
          summary.appointments = docs.map((a) => ({
            doctorName: a.doctorName,
            dateTime: toISO(a.dateTime),
            status: a.status,
          }));
        })
      );
    }

    if (allowedFields.has('medicalHistory')) {
      fetchTasks.push(
        fetchSubCollection(patientId, 'medicalHistory', 10).then((docs) => {
          summary.medicalHistory = docs.map((r) => ({
            condition: r.condition,
            diagnosedAt: toISO(r.diagnosedAt),
            isCurrent: r.isCurrent,
          }));
        })
      );
    }

    if (allowedFields.has('symptoms')) {
      fetchTasks.push(
        fetchSubCollection(patientId, 'symptoms', 5).then((docs) => {
          summary.symptoms = docs.map((s) => ({
            description: s.description,
            severity: s.severity,
            riskLevel: s.riskLevel,
            timestamp: toISO(s.timestamp),
            sharedWithDoctor: s.sharedWithDoctor,
          }));
        })
      );
    }

    await Promise.all(fetchTasks);

    return res.status(200).json({ summary });
  } catch (err) {
    logger.error(`patientController.getSummary error: ${err.message}`, { stack: err.stack });
    return res.status(500).json({
      error: 'InternalServerError',
      message: 'Could not retrieve patient summary.',
    });
  }
}

module.exports = { getSummary };
