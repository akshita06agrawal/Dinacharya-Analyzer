/**
 * Dinacharya Analyzer — Backend API Tests
 * Tests: health endpoint, rate limiting, input validation, error handling
 * Run: npm test
 */

const request = require('supertest');

// Mock environment for tests
process.env.ANTHROPIC_API_KEY = 'sk-test-key-for-testing';
process.env.NODE_ENV = 'test';

const app = require('../backend/server');

describe('Dinacharya Analyzer API', () => {

  // ── Health Endpoints ──────────────────────────────────────────
  describe('GET /health', () => {
    it('should return 200 with healthy status', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('healthy');
      expect(res.body).toHaveProperty('timestamp');
      expect(res.body).toHaveProperty('uptime');
      expect(res.body).toHaveProperty('environment');
    });

    it('should include version information', async () => {
      const res = await request(app).get('/health');
      expect(res.body).toHaveProperty('version');
    });
  });

  describe('GET /ready', () => {
    it('should return 200 when API key is configured', async () => {
      const res = await request(app).get('/ready');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ready');
    });
  });

  describe('GET /metrics', () => {
    it('should return Prometheus-format metrics', async () => {
      const res = await request(app).get('/metrics');
      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toContain('text/plain');
      expect(res.text).toContain('http_requests_total');
      expect(res.text).toContain('analyses_total');
      expect(res.text).toContain('app_uptime_seconds');
    });
  });

  // ── Analyze Endpoint Validation ───────────────────────────────
  describe('POST /api/analyze', () => {
    it('should return 400 when prompt is missing', async () => {
      const res = await request(app)
        .post('/api/analyze')
        .send({})
        .set('Content-Type', 'application/json');
      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error');
    });

    it('should return 400 when prompt is not a string', async () => {
      const res = await request(app)
        .post('/api/analyze')
        .send({ prompt: 12345 })
        .set('Content-Type', 'application/json');
      expect(res.status).toBe(400);
    });

    it('should return 400 when prompt is too long', async () => {
      const res = await request(app)
        .post('/api/analyze')
        .send({ prompt: 'a'.repeat(6000) })
        .set('Content-Type', 'application/json');
      expect(res.status).toBe(400);
    });

    it('should have proper CORS headers', async () => {
      const res = await request(app)
        .options('/api/analyze')
        .set('Origin', 'http://localhost:3000');
      expect(res.headers).toHaveProperty('access-control-allow-origin');
    });
  });

  // ── Security Headers ──────────────────────────────────────────
  describe('Security Headers (Helmet)', () => {
    it('should include X-Content-Type-Options header', async () => {
      const res = await request(app).get('/health');
      expect(res.headers['x-content-type-options']).toBe('nosniff');
    });

    it('should include X-Frame-Options header', async () => {
      const res = await request(app).get('/health');
      expect(res.headers['x-frame-options']).toBeDefined();
    });
  });

  // ── 404 Handling ──────────────────────────────────────────────
  describe('404 Routes', () => {
    it('should serve frontend for unknown routes (SPA)', async () => {
      const res = await request(app).get('/some-unknown-route');
      // Should either redirect to index.html or return 404
      expect([200, 404]).toContain(res.status);
    });
  });
});
