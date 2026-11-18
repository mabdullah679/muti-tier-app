// Cloudflare Pages Function: the Express API from backend/src/app.js, ported
// 1:1 (routes, JSON shapes, status codes, security headers). tests/parity/
// runs identical requests through Express and this module and diffs them.
// Validation is the backend's own module, so the rules cannot drift.
import validation from '../../backend/src/validation.js';

const { validateGreetBody } = validation;
const BODY_LIMIT_BYTES = 1024; // express.json({ limit: '1kb' })

// What helmet() sets in backend/src/app.js (helmet 8 defaults).
const SECURITY_HEADERS = {
  'content-security-policy':
    "default-src 'self';base-uri 'self';font-src 'self' https: data:;form-action 'self';frame-ancestors 'self';img-src 'self' data:;object-src 'none';script-src 'self';script-src-attr 'none';style-src 'self' https: 'unsafe-inline';upgrade-insecure-requests",
  'cross-origin-opener-policy': 'same-origin',
  'cross-origin-resource-policy': 'same-origin',
  'origin-agent-cluster': '?1',
  'referrer-policy': 'no-referrer',
  'strict-transport-security': 'max-age=31536000; includeSubDomains',
  'x-content-type-options': 'nosniff',
  'x-dns-prefetch-control': 'off',
  'x-download-options': 'noopen',
  'x-frame-options': 'SAMEORIGIN',
  'x-permitted-cross-domain-policies': 'none',
  'x-xss-protection': '0',
};

const started = Date.now();

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...SECURITY_HEADERS, 'content-type': 'application/json; charset=utf-8' },
  });
}

// Mirrors express.json(): strict mode (objects/arrays only), 1kb cap,
// empty or non-JSON content-type => {}.
async function readBody(request) {
  const type = request.headers.get('content-type') || '';
  if (!/^application\/(?:[\w.+-]+\+)?json(?:\s*;|$)/i.test(type)) return { body: {} };
  const buf = new Uint8Array(await request.arrayBuffer());
  if (buf.byteLength > BODY_LIMIT_BYTES) return { response: json(413, { error: 'Request body too large' }) };
  const text = new TextDecoder().decode(buf);
  if (text.trim() === '') return { body: {} };
  if (!/^[\x20\x09\x0a\x0d]*[{[]/.test(text)) return { response: json(400, { error: 'Malformed JSON body' }) };
  try {
    return { body: JSON.parse(text) };
  } catch {
    return { response: json(400, { error: 'Malformed JSON body' }) };
  }
}

export async function onRequest({ request }) {
  // Express defaults: case-insensitive, trailing slash ignored, query ignored.
  let route = new URL(request.url).pathname.toLowerCase();
  if (route.length > 1 && route.endsWith('/')) route = route.slice(0, -1);
  const method = request.method;

  if (method === 'GET' && route === '/api/endpoint') return json(200, { message: 'Hello from backend!' });

  if (method === 'GET' && route === '/api/health') {
    return json(200, {
      status: 'ok',
      servedBy: 'cloudflare-pages',
      uptimeSeconds: Math.round((Date.now() - started) / 1000),
    });
  }

  if (method === 'POST' && route === '/api/greet') {
    const { body, response } = await readBody(request);
    if (response) return response;
    const { value, error } = validateGreetBody(body);
    if (error) return json(400, { error });
    return json(200, { greeting: `Hello, ${value.name}!`, servedBy: 'cloudflare-pages' });
  }

  return json(404, { error: 'Not found' });
}
