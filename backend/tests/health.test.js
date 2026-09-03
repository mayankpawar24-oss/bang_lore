'use strict';

const request = require('supertest');

// Mock firebase
jest.mock('../src/config/firebase', () => ({
  admin: {
    apps: [{ name: 'test-app' }],
  },
  db: {
    collection: jest.fn().mockReturnValue({
      doc: jest.fn().mockReturnValue({
        get: jest.fn().mockResolvedValue({ exists: true }),
      }),
    }),
  },
  auth: {
    verifyIdToken: jest.fn(),
  },
}));

// Mock logger
jest.mock('../src/utils/logger', () => ({
  debug: jest.fn(),
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

describe('GET /health endpoint', () => {
  let app;

  beforeEach(() => {
    process.env.AI_PROVIDER = '';
    process.env.FIREBASE_PROJECT_ID = 'continuum-health-b54cb';
    app = require('../src/index');
  });

  test('returns 200 OK with health status when AI_PROVIDER is blank', async () => {
    process.env.AI_PROVIDER = '';
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.firebaseAdmin).toBe(true);
    expect(res.body.aiEnabled).toBe(false);
    expect(res.body.aiProvider).toBe('none');
    expect(res.body).not.toHaveProperty('OPENAI_API_KEY');
    expect(res.body).not.toHaveProperty('secret');
  });
});
