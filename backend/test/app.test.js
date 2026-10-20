'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { createApp } = require('../src/app');
const { validateGreetBody, NAME_MAX } = require('../src/validation');
const { loadConfig } = require('../src/config');

test('GET /healthz is ok', async () => {
  const res = await request(createApp()).get('/healthz');
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { status: 'ok' });
});

test('GET /readyz is 200 normally and 503 once shutting down', async () => {
  const state = { shuttingDown: false };
  const app = createApp({ state });
  assert.equal((await request(app).get('/readyz')).status, 200);
  state.shuttingDown = true;
  const res = await request(app).get('/readyz');
  assert.equal(res.status, 503);
  assert.equal(res.body.status, 'shutting_down');
});

test('GET /api/endpoint keeps the original contract', async () => {
  const res = await request(createApp()).get('/api/endpoint');
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { message: 'Hello from backend!' });
});

test('GET /api/health reports status and the serving pod', async () => {
  const res = await request(createApp()).get('/api/health');
  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'ok');
  assert.equal(typeof res.body.servedBy, 'string');
});

test('security headers are set and x-powered-by is hidden', async () => {
  const res = await request(createApp()).get('/api/endpoint');
  assert.equal(res.headers['x-powered-by'], undefined);
  assert.equal(res.headers['x-content-type-options'], 'nosniff');
});

test('POST /api/greet greets a valid name (trimmed)', async () => {
  const res = await request(createApp()).post('/api/greet').send({ name: '  Ada Lovelace ' });
  assert.equal(res.status, 200);
  assert.equal(res.body.greeting, 'Hello, Ada Lovelace!');
});

test('POST /api/greet rejects bad input with 400', async () => {
  const app = createApp();
  const bad = [
    {},
    { name: 42 },
    { name: '   ' },
    { name: 'x'.repeat(NAME_MAX + 1) },
    { name: '<script>alert(1)</script>' },
    { name: '1234' },
    [],
  ];
  for (const body of bad) {
    const res = await request(app).post('/api/greet').send(body);
    assert.equal(res.status, 400, `expected 400 for ${JSON.stringify(body)}`);
    assert.equal(typeof res.body.error, 'string');
  }
});

test('POST /api/greet accepts the maximum length name', async () => {
  const res = await request(createApp()).post('/api/greet').send({ name: 'x'.repeat(NAME_MAX) });
  assert.equal(res.status, 200);
});

test('malformed JSON is a 400, oversize body is a 413', async () => {
  const app = createApp();
  const malformed = await request(app).post('/api/greet').set('Content-Type', 'application/json').send('{nope');
  assert.equal(malformed.status, 400);
  assert.equal(malformed.body.error, 'Malformed JSON body');
  const big = await request(app).post('/api/greet').send({ name: 'a', pad: 'b'.repeat(2000) });
  assert.equal(big.status, 413);
});

test('unknown routes return JSON 404', async () => {
  const res = await request(createApp()).get('/nope');
  assert.equal(res.status, 404);
  assert.deepEqual(res.body, { error: 'Not found' });
});

test('GET /metrics exposes Prometheus metrics including request histogram', async () => {
  const app = createApp();
  await request(app).get('/api/endpoint');
  const res = await request(app).get('/metrics');
  assert.equal(res.status, 200);
  assert.match(res.text, /http_request_duration_seconds_count\{[^}]*route="\/api\/endpoint"[^}]*status_code="200"\} 1/);
  assert.match(res.text, /process_cpu_user_seconds_total/);
});

test('validateGreetBody unit: accepts unicode names, rejects null', () => {
  assert.deepEqual(validateGreetBody({ name: 'Zoë O\'Neil-Smith' }), { value: { name: 'Zoë O\'Neil-Smith' } });
  assert.ok(validateGreetBody(null).error);
});

test('loadConfig defaults and rejects invalid PORT', () => {
  const saved = process.env.PORT;
  delete process.env.PORT;
  assert.equal(loadConfig().port, 3001);
  process.env.PORT = 'abc';
  assert.throws(() => loadConfig(), /Invalid PORT/);
  if (saved === undefined) delete process.env.PORT; else process.env.PORT = saved;
});
