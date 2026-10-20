'use strict';

const os = require('os');
const express = require('express');
const helmet = require('helmet');
const pino = require('pino');
const pinoHttp = require('pino-http');
const client = require('prom-client');
const { validateGreetBody } = require('./validation');

function createApp({ logger = pino({ level: 'silent' }), state = { shuttingDown: false } } = {}) {
  const app = express();
  app.disable('x-powered-by');

  const registry = new client.Registry();
  client.collectDefaultMetrics({ register: registry });
  const httpDuration = new client.Histogram({
    name: 'http_request_duration_seconds',
    help: 'HTTP request duration in seconds',
    labelNames: ['method', 'route', 'status_code'],
    buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5],
    registers: [registry],
  });

  app.use(helmet());
  app.use(
    pinoHttp({
      logger,
      // Probe and scrape traffic is noise in the application log.
      autoLogging: { ignore: (req) => ['/healthz', '/readyz', '/metrics'].includes(req.url) },
    }),
  );
  app.use((req, res, next) => {
    const end = httpDuration.startTimer();
    res.on('finish', () => {
      const route = req.route ? req.baseUrl + req.route.path : 'unmatched';
      end({ method: req.method, route, status_code: res.statusCode });
    });
    next();
  });
  app.use(express.json({ limit: '1kb' }));

  // Liveness: the process is up and the event loop is responsive.
  app.get('/healthz', (req, res) => res.json({ status: 'ok' }));

  // Readiness: flips to 503 during shutdown so traffic drains before exit.
  app.get('/readyz', (req, res) => {
    if (state.shuttingDown) return res.status(503).json({ status: 'shutting_down' });
    return res.json({ status: 'ready' });
  });

  app.get('/metrics', async (req, res, next) => {
    try {
      res.set('Content-Type', registry.contentType);
      res.end(await registry.metrics());
    } catch (err) {
      next(err);
    }
  });

  app.get('/api/endpoint', (req, res) => {
    res.json({ message: 'Hello from backend!' });
  });

  app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', servedBy: os.hostname(), uptimeSeconds: Math.round(process.uptime()) });
  });

  app.post('/api/greet', (req, res) => {
    const { value, error } = validateGreetBody(req.body);
    if (error) return res.status(400).json({ error });
    return res.json({ greeting: `Hello, ${value.name}!`, servedBy: os.hostname() });
  });

  app.use((req, res) => {
    res.status(404).json({ error: 'Not found' });
  });

  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'Malformed JSON body' });
    if (err.type === 'entity.too.large') return res.status(413).json({ error: 'Request body too large' });
    req.log.error({ err }, 'unhandled error');
    return res.status(500).json({ error: 'Internal server error' });
  });

  return app;
}

module.exports = { createApp };
