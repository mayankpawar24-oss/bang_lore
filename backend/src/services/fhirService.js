'use strict';

/**
 * src/services/fhirService.js
 * Converts Firestore patient data into a basic FHIR R4 Bundle (JSON).
 *
 * Resources generated:
 *   - Patient
 *   - MedicationStatement (per active medication)
 *   - Observation (per vital sign reading)
 *   - Appointment (per appointment record)
 *   - Condition (per medical history record)
 *
 * Export:
 *   generateFhirBundle(patientId) → FHIR Bundle object
 */

const { db } = require('../config/firebase');
const logger = require('../utils/logger');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function toISO(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return String(value);
}

function fhirTimestamp() {
  return new Date().toISOString();
}

async function getCollection(patientId, collectionName, limit = 50) {
  const snap = await db
    .collection('patients')
    .doc(patientId)
    .collection(collectionName)
    .limit(limit)
    .get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

// ---------------------------------------------------------------------------
// FHIR Resource builders
// ---------------------------------------------------------------------------

function buildPatientResource(profile, patientId) {
  return {
    resourceType: 'Patient',
    id: patientId,
    meta: { lastUpdated: fhirTimestamp() },
    identifier: [
      {
        system: 'urn:continuum-health:patient-id',
        value: patientId,
      },
    ],
    name: [
      {
        use: 'official',
        text: profile.name || 'Unknown',
      },
    ],
    ...(profile.age != null
      ? {
          extension: [
            {
              url: 'http://hl7.org/fhir/StructureDefinition/patient-age',
              valueAge: { value: profile.age, unit: 'yr', system: 'http://unitsofmeasure.org', code: 'a' },
            },
          ],
        }
      : {}),
  };
}

function buildMedicationStatementResource(med, patientId) {
  return {
    resourceType: 'MedicationStatement',
    id: med.id,
    status: med.active !== false ? 'active' : 'stopped',
    subject: { reference: `Patient/${patientId}` },
    medicationCodeableConcept: {
      text: med.name,
    },
    dosage: [
      {
        text: `${med.dosage || ''} ${med.frequency || ''}`.trim(),
        timing: {
          repeat: {
            timeOfDay: med.times || [],
          },
        },
      },
    ],
  };
}

function buildObservationResource(vital, patientId) {
  const observations = [];
  const baseMeta = {
    resourceType: 'Observation',
    status: 'final',
    subject: { reference: `Patient/${patientId}` },
    effectiveDateTime: toISO(vital.recordedAt),
  };

  if (vital.heartRate != null) {
    observations.push({
      ...baseMeta,
      id: `${vital.id}-hr`,
      code: {
        coding: [
          { system: 'http://loinc.org', code: '8867-4', display: 'Heart rate' },
        ],
        text: 'Heart rate',
      },
      valueQuantity: { value: vital.heartRate, unit: 'beats/min', system: 'http://unitsofmeasure.org', code: '/min' },
    });
  }

  if (vital.systolic != null && vital.diastolic != null) {
    observations.push({
      ...baseMeta,
      id: `${vital.id}-bp`,
      code: {
        coding: [
          { system: 'http://loinc.org', code: '55284-4', display: 'Blood pressure systolic and diastolic' },
        ],
        text: 'Blood pressure',
      },
      component: [
        {
          code: { coding: [{ system: 'http://loinc.org', code: '8480-6', display: 'Systolic blood pressure' }] },
          valueQuantity: { value: vital.systolic, unit: 'mmHg', system: 'http://unitsofmeasure.org', code: 'mm[Hg]' },
        },
        {
          code: { coding: [{ system: 'http://loinc.org', code: '8462-4', display: 'Diastolic blood pressure' }] },
          valueQuantity: { value: vital.diastolic, unit: 'mmHg', system: 'http://unitsofmeasure.org', code: 'mm[Hg]' },
        },
      ],
    });
  }

  if (vital.spo2 != null) {
    observations.push({
      ...baseMeta,
      id: `${vital.id}-spo2`,
      code: {
        coding: [
          { system: 'http://loinc.org', code: '59408-5', display: 'Oxygen saturation in Arterial blood by Pulse oximetry' },
        ],
        text: 'SpO2',
      },
      valueQuantity: { value: vital.spo2, unit: '%', system: 'http://unitsofmeasure.org', code: '%' },
    });
  }

  if (vital.weight != null) {
    observations.push({
      ...baseMeta,
      id: `${vital.id}-weight`,
      code: {
        coding: [
          { system: 'http://loinc.org', code: '29463-7', display: 'Body weight' },
        ],
        text: 'Body weight',
      },
      valueQuantity: { value: vital.weight, unit: 'kg', system: 'http://unitsofmeasure.org', code: 'kg' },
    });
  }

  return observations;
}

function buildAppointmentResource(appt, patientId) {
  const statusMap = {
    scheduled: 'booked',
    completed: 'fulfilled',
    cancelled: 'cancelled',
    pending: 'pending',
  };
  return {
    resourceType: 'Appointment',
    id: appt.id,
    status: statusMap[appt.status] || 'booked',
    participant: [
      { actor: { reference: `Patient/${patientId}` }, status: 'accepted' },
      ...(appt.doctorId
        ? [{ actor: { reference: `Practitioner/${appt.doctorId}`, display: appt.doctorName }, status: 'accepted' }]
        : []),
    ],
    start: toISO(appt.dateTime),
    comment: appt.notes || undefined,
  };
}

function buildConditionResource(record, patientId) {
  return {
    resourceType: 'Condition',
    id: record.id,
    clinicalStatus: {
      coding: [
        {
          system: 'http://terminology.hl7.org/CodeSystem/condition-clinical',
          code: record.isCurrent ? 'active' : 'resolved',
        },
      ],
    },
    subject: { reference: `Patient/${patientId}` },
    code: { text: record.condition },
    onsetDateTime: toISO(record.diagnosedAt),
    note: record.notes ? [{ text: record.notes }] : undefined,
  };
}

// ---------------------------------------------------------------------------
// Bundle assembler
// ---------------------------------------------------------------------------

function toEntry(resource) {
  return {
    fullUrl: `urn:uuid:${resource.id}`,
    resource,
  };
}

// ---------------------------------------------------------------------------
// Main export
// ---------------------------------------------------------------------------

/**
 * Generate a FHIR R4 Bundle for the given patient.
 *
 * @param {string} patientId - Verified patient UID.
 * @returns {Promise<object>} FHIR R4 Bundle JSON object
 */
async function generateFhirBundle(patientId) {
  if (!patientId) throw new Error('generateFhirBundle: patientId is required.');

  logger.debug(`fhirService: generating FHIR bundle for patient ${patientId}`);

  // Fetch patient profile doc
  const profileSnap = await db.collection('patients').doc(patientId).get();
  if (!profileSnap.exists) {
    throw new Error(`Patient ${patientId} not found.`);
  }
  const profile = { id: profileSnap.id, ...profileSnap.data() };

  // Parallel fetch of sub-collections
  const [vitals, medications, appointments, medHistory] = await Promise.all([
    getCollection(patientId, 'vitals', 30),
    getCollection(patientId, 'medications', 30),
    getCollection(patientId, 'appointments', 30),
    getCollection(patientId, 'medicalHistory', 30),
  ]);

  const entries = [];

  // Patient resource
  entries.push(toEntry(buildPatientResource(profile, patientId)));

  // Medications
  for (const med of medications) {
    entries.push(toEntry(buildMedicationStatementResource(med, patientId)));
  }

  // Vitals → Observations (may produce multiple obs per vital record)
  for (const vital of vitals) {
    const obsArr = buildObservationResource(vital, patientId);
    for (const obs of obsArr) {
      entries.push(toEntry(obs));
    }
  }

  // Appointments
  for (const appt of appointments) {
    entries.push(toEntry(buildAppointmentResource(appt, patientId)));
  }

  // Medical history → Conditions
  for (const record of medHistory) {
    entries.push(toEntry(buildConditionResource(record, patientId)));
  }

  return {
    resourceType: 'Bundle',
    type: 'collection',
    timestamp: fhirTimestamp(),
    total: entries.length,
    entry: entries,
  };
}

module.exports = { generateFhirBundle };
