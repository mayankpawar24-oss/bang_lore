'use strict';

/**
 * tests/ai.test.js
 * Jest test suite for the AI agent pipeline.
 *
 * Tests:
 *  - safetyAgent: emergency keyword detection
 *  - safetyAgent: non-emergency passthrough + disclaimer injection
 *  - sentinelAgent: emergency response formatting
 *  - sentinelAgent: normal response formatting
 *  - contextAgent: structure validation (Firestore mocked)
 */

// ---------------------------------------------------------------------------
// Mock Firebase so tests don't need a real project
// ---------------------------------------------------------------------------
jest.mock('../src/config/firebase', () => ({
  admin: {},
  db: {
    collection: jest.fn(),
  },
  auth: {
    verifyIdToken: jest.fn(),
  },
}));

// Mock AI provider — we don't want real HTTP calls in tests
jest.mock('../src/utils/aiProvider', () => ({
  sendToAI: jest.fn().mockResolvedValue({ content: 'Mocked AI response.', provider: 'openai' }),
}));

// Mock logger to suppress console output during tests
jest.mock('../src/utils/logger', () => ({
  debug: jest.fn(),
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

// ---------------------------------------------------------------------------
// Unit: safetyAgent
// ---------------------------------------------------------------------------

const { checkSafety } = require('../src/agents/safetyAgent');

describe('safetyAgent — emergency detection', () => {
  test('detects "chest pain" in user message', () => {
    const result = checkSafety('You might want to monitor this.', 'I have severe chest pain');
    expect(result.emergencyDetected).toBe(true);
    expect(result.isSafe).toBe(false);
    expect(result.emergencyMessage).toContain('EMERGENCY');
    expect(result.safeResponse).toContain('911');
  });

  test('detects "can\'t breathe" in user message', () => {
    const result = checkSafety('Normal clinical response.', "I can't breathe properly");
    expect(result.emergencyDetected).toBe(true);
    expect(result.safeResponse).toContain('emergency services');
  });

  test('detects "stroke" in clinical response', () => {
    const result = checkSafety(
      'This could indicate a stroke.',
      'My face feels droopy and I have weakness'
    );
    expect(result.emergencyDetected).toBe(true);
  });

  test('detects "suicidal" in user message', () => {
    const result = checkSafety('Normal response.', 'I am feeling suicidal');
    expect(result.emergencyDetected).toBe(true);
  });

  test('detects "overdose" keyword', () => {
    const result = checkSafety('Possible overdose situation.', 'I think I took too many pills');
    // "overdose" is in the clinical response — should be detected
    expect(result.emergencyDetected).toBe(true);
  });
});

describe('safetyAgent — non-emergency passthrough', () => {
  test('passes through a normal response with disclaimer appended', () => {
    const clinical = 'You may want to rest and drink plenty of fluids.';
    const result = checkSafety(clinical, 'I have a mild headache');
    expect(result.emergencyDetected).toBe(false);
    expect(result.isSafe).toBe(true);
    expect(result.emergencyMessage).toBeNull();
    expect(result.safeResponse).toContain(clinical);
    expect(result.safeResponse).toContain('educational purposes only');
  });

  test('sanitises inappropriate certainty language', () => {
    const clinical = 'You definitely have hypertension.';
    const result = checkSafety(clinical, 'My blood pressure is high');
    expect(result.emergencyDetected).toBe(false);
    expect(result.safeResponse).not.toContain('definitely have');
    expect(result.safeResponse).toContain('may have');
  });

  test('does not double-append disclaimer if already present', () => {
    const clinical =
      'Rest and stay hydrated. This information is for educational purposes only and does not constitute medical advice. Always consult a qualified healthcare professional before making any medical decisions.';
    const result = checkSafety(clinical, 'I feel tired');
    const disclaimerCount = (result.safeResponse.match(/educational purposes only/g) || []).length;
    expect(disclaimerCount).toBe(1);
  });

  test('returns safeResponse without emergency content for routine query', () => {
    const result = checkSafety(
      'This sounds like a common cold. Rest and fluids are recommended.',
      'I have a runny nose and sneezing'
    );
    expect(result.isSafe).toBe(true);
    expect(result.safeResponse).not.toContain('🚨');
  });
});

// ---------------------------------------------------------------------------
// Unit: sentinelAgent
// ---------------------------------------------------------------------------

const { generateFinalResponse } = require('../src/agents/sentinelAgent');

describe('sentinelAgent — emergency response formatting', () => {
  const emergencySafetyResult = {
    isSafe: false,
    emergencyDetected: true,
    emergencyMessage: '🚨 EMERGENCY DETECTED 🚨 Call 911 immediately.',
    safeResponse: '🚨 EMERGENCY DETECTED 🚨 Call 911 immediately.',
  };

  const clinicalResponse = { reasoning: 'Some clinical text.', confidenceLevel: 'high' };
  const patientContext = { patientId: 'patient-123', profile: { name: 'Test' } };

  test('returns emergency answer immediately when emergencyDetected=true', () => {
    const result = generateFinalResponse(clinicalResponse, emergencySafetyResult, patientContext);
    expect(result.answer).toContain('EMERGENCY');
    expect(result.recommendedAction).toBe('emergency');
  });

  test('sets confidence to "high" for emergencies', () => {
    const result = generateFinalResponse(clinicalResponse, emergencySafetyResult, patientContext);
    expect(result.confidence).toBe('high');
  });

  test('includes emergency safety note', () => {
    const result = generateFinalResponse(clinicalResponse, emergencySafetyResult, patientContext);
    expect(result.safetyNote).toContain('emergency services');
  });
});

describe('sentinelAgent — normal response formatting', () => {
  const normalSafetyResult = {
    isSafe: true,
    emergencyDetected: false,
    emergencyMessage: null,
    safeResponse:
      'You should consult your doctor about this. Rest and stay hydrated. This information is for educational purposes only.',
  };

  const clinicalResponse = { reasoning: 'Normal reasoning.', confidenceLevel: 'medium' };
  const patientContext = { patientId: 'patient-456', profile: { name: 'Jane' } };

  test('returns formatted answer with non-null content', () => {
    const result = generateFinalResponse(clinicalResponse, normalSafetyResult, patientContext);
    expect(result.answer).toBeTruthy();
    expect(typeof result.answer).toBe('string');
  });

  test('propagates confidenceLevel from clinical response', () => {
    const result = generateFinalResponse(clinicalResponse, normalSafetyResult, patientContext);
    expect(result.confidence).toBe('medium');
  });

  test('recommends see_doctor when response mentions consulting a doctor', () => {
    const result = generateFinalResponse(clinicalResponse, normalSafetyResult, patientContext);
    expect(result.recommendedAction).toBe('see_doctor');
  });

  test('includes standard safety note', () => {
    const result = generateFinalResponse(clinicalResponse, normalSafetyResult, patientContext);
    expect(result.safetyNote).toContain('informational purposes only');
  });

  test('has all required response fields', () => {
    const result = generateFinalResponse(clinicalResponse, normalSafetyResult, patientContext);
    expect(result).toHaveProperty('answer');
    expect(result).toHaveProperty('confidence');
    expect(result).toHaveProperty('recommendedAction');
    expect(result).toHaveProperty('safetyNote');
  });
});

// ---------------------------------------------------------------------------
// Unit: contextAgent (Firestore mocked)
// ---------------------------------------------------------------------------

describe('contextAgent — structure validation', () => {
  const { db } = require('../src/config/firebase');

  /**
   * Helper to build a Firestore-like mock that returns given docs.
   */
  function mockFirestoreDoc(data) {
    return {
      get: jest.fn().mockResolvedValue({
        exists: true,
        id: 'mock-id',
        data: () => data,
      }),
    };
  }

  function mockFirestoreCollection(docs = []) {
    const snap = {
      docs: docs.map((d) => ({ id: d.id || 'doc-id', data: () => d })),
    };
    const queryObj = {
      orderBy: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      get: jest.fn().mockResolvedValue(snap),
    };
    return queryObj;
  }

  beforeEach(() => {
    // Reset mocks between tests
    db.collection.mockReset();
  });

  test('buildPatientContext returns required top-level keys', async () => {
    const mockPatientData = {
      name: 'John Doe',
      age: 45,
      conditions: ['Hypertension'],
      status: 'stable',
    };

    // Mock the patients/{patientId} document
    const mockDocRef = mockFirestoreDoc(mockPatientData);
    const mockCollRef = mockFirestoreCollection([]);

    db.collection.mockImplementation((collName) => {
      if (collName === 'patients') {
        return {
          doc: jest.fn().mockReturnValue({
            ...mockDocRef,
            collection: jest.fn().mockReturnValue(mockCollRef),
          }),
        };
      }
      return { doc: jest.fn() };
    });

    const { buildPatientContext } = require('../src/agents/contextAgent');
    const context = await buildPatientContext('patient-test-123', 'full');

    expect(context).toHaveProperty('patientId', 'patient-test-123');
    expect(context).toHaveProperty('profile');
    expect(context).toHaveProperty('recentVitals');
    expect(context).toHaveProperty('medications');
    expect(context).toHaveProperty('upcomingAppointments');
    expect(context).toHaveProperty('familyHistory');
    expect(context).toHaveProperty('recentSymptoms');
  });

  test('profile contains expected fields', async () => {
    const mockPatientData = { name: 'Jane Smith', age: 30, conditions: ['Asthma'] };
    const mockDocRef = mockFirestoreDoc(mockPatientData);
    const mockCollRef = mockFirestoreCollection([]);

    db.collection.mockImplementation(() => ({
      doc: jest.fn().mockReturnValue({
        ...mockDocRef,
        collection: jest.fn().mockReturnValue(mockCollRef),
      }),
    }));

    const { buildPatientContext } = require('../src/agents/contextAgent');
    const context = await buildPatientContext('patient-jane', 'full');

    expect(context.profile.name).toBe('Jane Smith');
    expect(context.profile.age).toBe(30);
    expect(context.profile.conditions).toContain('Asthma');
  });

  test('throws if patientId is missing', async () => {
    const { buildPatientContext } = require('../src/agents/contextAgent');
    await expect(buildPatientContext(null)).rejects.toThrow('patientId is required');
  });

  test('throws if patient document does not exist', async () => {
    db.collection.mockImplementation(() => ({
      doc: jest.fn().mockReturnValue({
        get: jest.fn().mockResolvedValue({ exists: false }),
        collection: jest.fn().mockReturnValue(mockFirestoreCollection([])),
      }),
    }));

    const { buildPatientContext } = require('../src/agents/contextAgent');
    await expect(buildPatientContext('nonexistent-id')).rejects.toThrow('not found');
  });
});
