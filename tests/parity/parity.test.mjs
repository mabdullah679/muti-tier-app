// Runs the SAME request cases against the Express app (real HTTP) and the
// Pages Function module (a Request object), and asserts identical
// status, headers and body.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import path from 'node:path';

const require = createRequire(import.meta.url);
const root = path.resolve(import.meta.dirname, '../..');
const { createApp } = require(path.join(root, 'backend/src/app.js'));
const fn = await import(pathToFileURL(path.join(root, 'functions/api/[[path]].js')).href);

// Headers that legitimately differ per server/response.
const VOLATILE = new Set(['date', 'etag', 'content-length', 'connection', 'keep-alive']);
// Body fields that are per-instance by design (hostname/uptime); type is compared instead.
const DYNAMIC = new Set(['servedBy', 'uptimeSeconds']);

let server;
let base;
before(async () => {
  server = createApp().listen(0);
  await new Promise((r) => server.once('listening', r));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

const J = { 'content-type': 'application/json' };
const cases = [
  ['GET /api/endpoint', 'GET', '/api/endpoint'],
  ['GET /api/health', 'GET', '/api/health'],
  ['GET /api/health with trailing slash', 'GET', '/api/health/'],
  ['GET /api/health with query string', 'GET', '/api/health?x=1'],
  ['GET /api/HEALTH (express routing is case-insensitive)', 'GET', '/api/HEALTH'],
  ['POST /api/greet valid', 'POST', '/api/greet', J, JSON.stringify({ name: 'Ada' })],
  ['POST /api/greet trims name', 'POST', '/api/greet', J, JSON.stringify({ name: '  Ada Lovelace  ' })],
  ['POST /api/greet unicode name', 'POST', '/api/greet', J, JSON.stringify({ name: 'Zoë-Émile' })],
  ['POST /api/greet missing name', 'POST', '/api/greet', J, '{}'],
  ['POST /api/greet non-string name', 'POST', '/api/greet', J, JSON.stringify({ name: 5 })],
  ['POST /api/greet blank name', 'POST', '/api/greet', J, JSON.stringify({ name: '   ' })],
  ['POST /api/greet too long name', 'POST', '/api/greet', J, JSON.stringify({ name: 'a'.repeat(41) })],
  ['POST /api/greet bad chars', 'POST', '/api/greet', J, JSON.stringify({ name: '<script>' })],
  ['POST /api/greet array body', 'POST', '/api/greet', J, '[1]'],
  ['POST /api/greet null body', 'POST', '/api/greet', J, 'null'],
  ['POST /api/greet malformed JSON', 'POST', '/api/greet', J, '{nope'],
  ['POST /api/greet body over 1kb', 'POST', '/api/greet', J, JSON.stringify({ name: 'a', pad: 'x'.repeat(2000) })],
  ['POST /api/greet no content-type', 'POST', '/api/greet', {}, JSON.stringify({ name: 'Ada' })],
  ['POST /api/greet empty body', 'POST', '/api/greet', J, ''],
  ['GET /api/greet (wrong method is a 404 in express)', 'GET', '/api/greet'],
  ['POST /api/health (wrong method)', 'POST', '/api/health', J, '{}'],
  ['GET /api/unknown', 'GET', '/api/unknown'],
  ['GET /api/', 'GET', '/api/'],
];

async function viaExpress(method, p, headers, body) {
  return fetch(base + p, { method, headers, body: body === '' ? undefined : body });
}
async function viaFunction(method, p, headers, body) {
  const request = new Request('https://example.pages.dev' + p, {
    method,
    headers,
    body: method === 'GET' || body === '' ? undefined : body,
  });
  const handler = fn[`onRequest${method[0] + method.slice(1).toLowerCase()}`] ?? fn.onRequest;
  return handler({ request, env: {}, params: {}, waitUntil() {}, next: async () => new Response('next', { status: 599 }) });
}

async function normalise(res) {
  const headers = {};
  for (const [k, v] of res.headers) if (!VOLATILE.has(k)) headers[k] = v;
  const text = await res.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = text;
  }
  const types = {};
  if (body && typeof body === 'object' && !Array.isArray(body)) {
    for (const k of Object.keys(body)) {
      if (DYNAMIC.has(k)) {
        types[k] = typeof body[k];
        body[k] = '<dynamic>';
      }
    }
  }
  return { status: res.status, headers, body, types };
}

for (const [name, method, p, headers = {}, body = ''] of cases) {
  test(`parity: ${name}`, async () => {
    const a = await normalise(await viaExpress(method, p, headers, body));
    const b = await normalise(await viaFunction(method, p, headers, body));
    assert.deepEqual(b, a);
  });
}

test('sanity: the cases cover success, 400, 404 and 413', async () => {
  const seen = new Set();
  for (const [, method, p, headers = {}, body = ''] of cases) {
    seen.add((await viaExpress(method, p, headers, body)).status);
  }
  for (const s of [200, 400, 404, 413]) assert.ok(seen.has(s), `no case produced ${s}`);
});
