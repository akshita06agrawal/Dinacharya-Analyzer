/**
 * Dinacharya Analyzer — Backend API Server
 * Node.js + Express | Production-ready with health checks, metrics, structured logging
 */

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const path = require('path');
const fs = require('fs');

// ── Load .env ──────────────────────────────────────────────────────
const envPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
  fs.readFileSync(envPath, 'utf8').split('\n').forEach(line => {
    const [k, ...v] = line.split('=');
    if (k && !k.startsWith('#') && v.length) process.env[k.trim()] = v.join('=').trim();
  });
}

const app = express();
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';

// ── Metrics counters (in-memory for demo; use Prometheus in prod) ──
const metrics = {
  requestsTotal: 0,
  requestsSuccess: 0,
  requestsError: 0,
  analysesTotal: 0,
  uptimeStart: Date.now(),
};

// ── Middleware ─────────────────────────────────────────────────────
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
      fontSrc: ["'self'", "https://fonts.gstatic.com"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:"],
    }
  }
}));
app.use(cors({ origin: process.env.ALLOWED_ORIGIN || '*' }));
app.use(express.json({ limit: '10kb' }));

// Structured JSON logging
app.use(morgan((tokens, req, res) => {
  metrics.requestsTotal++;
  const status = tokens.status(req, res);
  if (status >= 400) metrics.requestsError++;
  else metrics.requestsSuccess++;

  return JSON.stringify({
    timestamp: new Date().toISOString(),
    method: tokens.method(req, res),
    url: tokens.url(req, res),
    status: parseInt(status),
    responseTime: `${tokens['response-time'](req, res)}ms`,
    userAgent: req.headers['user-agent'],
    env: NODE_ENV,
  });
}));

// Rate limiting (protects API from abuse)
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  message: { error: 'Too many requests. Please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);

// ── Serve Frontend ─────────────────────────────────────────────────
app.use(express.static(path.join(__dirname, '..', 'frontend', 'public')));

// ── API Routes ─────────────────────────────────────────────────────

// Health check endpoint (used by Kubernetes liveness/readiness probes)
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: `${Math.floor((Date.now() - metrics.uptimeStart) / 1000)}s`,
    environment: NODE_ENV,
    version: process.env.APP_VERSION || '1.0.0',
  });
});

// Readiness probe (Kubernetes)
app.get('/ready', (req, res) => {
  const hasApiKey = !!process.env.ANTHROPIC_API_KEY;
  if (!hasApiKey) {
    return res.status(503).json({ status: 'not_ready', reason: 'ANTHROPIC_API_KEY missing' });
  }
  res.status(200).json({ status: 'ready' });
});

// Prometheus-compatible metrics endpoint
app.get('/metrics', (req, res) => {
  const uptime = Math.floor((Date.now() - metrics.uptimeStart) / 1000);
  const output = [
    '# HELP http_requests_total Total HTTP requests',
    '# TYPE http_requests_total counter',
    `http_requests_total{status="success"} ${metrics.requestsSuccess}`,
    `http_requests_total{status="error"} ${metrics.requestsError}`,
    '',
    '# HELP analyses_total Total analyses performed',
    '# TYPE analyses_total counter',
    `analyses_total ${metrics.analysesTotal}`,
    '',
    '# HELP app_uptime_seconds Application uptime in seconds',
    '# TYPE app_uptime_seconds gauge',
    `app_uptime_seconds ${uptime}`,
    '',
    '# HELP nodejs_memory_heap_used_bytes Node.js heap memory',
    '# TYPE nodejs_memory_heap_used_bytes gauge',
    `nodejs_memory_heap_used_bytes ${process.memoryUsage().heapUsed}`,
  ].join('\n');
  res.set('Content-Type', 'text/plain');
  res.send(output);
});

// Main analyze endpoint
app.post('/api/analyze', async (req, res) => {
  const { prompt } = req.body;

  if (!prompt || typeof prompt !== 'string' || prompt.length > 5000) {
    return res.status(400).json({ error: 'Invalid request: prompt missing or too long.' });
  }

  if (!process.env.ANTHROPIC_API_KEY) {
    console.error(JSON.stringify({ level: 'ERROR', message: 'ANTHROPIC_API_KEY not configured', timestamp: new Date().toISOString() }));
    return res.status(500).json({ error: 'Server configuration error. Contact administrator.' });
  }

  try {
    const https = require('https');
    const body = JSON.stringify({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1500,
      messages: [{ role: 'user', content: prompt }],
    });

    const result = await new Promise((resolve, reject) => {
      const options = {
        hostname: 'api.anthropic.com',
        path: '/v1/messages',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': process.env.ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01',
          'Content-Length': Buffer.byteLength(body),
        },
      };

      const apiReq = https.request(options, (apiRes) => {
        let data = '';
        apiRes.on('data', chunk => data += chunk);
        apiRes.on('end', () => {
          try {
            const parsed = JSON.parse(data);
            if (apiRes.statusCode !== 200) {
              reject(new Error(parsed?.error?.message || `API error ${apiRes.statusCode}`));
            } else {
              resolve(parsed);
            }
          } catch (e) {
            reject(new Error('Failed to parse API response'));
          }
        });
      });

      apiReq.on('error', reject);
      apiReq.setTimeout(30000, () => { apiReq.destroy(); reject(new Error('Request timeout')); });
      apiReq.write(body);
      apiReq.end();
    });

    const raw = (result?.content || []).map(b => b.text || '').join('');
    const clean = raw.replace(/```json[\s\S]*?```/g, m => m.slice(7, -3)).replace(/```/g, '').trim();
    const analysisResult = JSON.parse(clean);

    metrics.analysesTotal++;
    console.log(JSON.stringify({ level: 'INFO', message: 'Analysis completed', score: analysisResult.score, timestamp: new Date().toISOString() }));

    res.status(200).json(analysisResult);

  } catch (err) {
    console.error(JSON.stringify({ level: 'ERROR', message: err.message, timestamp: new Date().toISOString() }));
    res.status(500).json({ error: err.message || 'Analysis failed. Please try again.' });
  }
});

// Catch-all: serve frontend for SPA routing
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '..', 'frontend', 'public', 'index.html'));
});

// ── Start Server ───────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(JSON.stringify({
    level: 'INFO',
    message: `Dinacharya Analyzer started`,
    port: PORT,
    environment: NODE_ENV,
    timestamp: new Date().toISOString(),
  }));
});

// Graceful shutdown (important for Kubernetes rolling updates)
process.on('SIGTERM', () => {
  console.log(JSON.stringify({ level: 'INFO', message: 'SIGTERM received — shutting down gracefully', timestamp: new Date().toISOString() }));
  process.exit(0);
});
process.on('SIGINT', () => process.exit(0));

module.exports = app;
