// All calls are same-origin and relative: in the cluster the Nginx ingress
// routes /api/* to the backend Service, so the browser never needs to know
// the backend's address (and no CORS is involved).
async function request(path, options) {
  const res = await fetch(path, options);
  let body = null;
  try {
    body = await res.json();
  } catch (e) {
    body = null;
  }
  if (!res.ok) {
    const message = (body && body.error) || `Request failed (${res.status})`;
    throw new Error(message);
  }
  return body;
}

export const getHealth = () => request('/api/health');

export const greet = (name) =>
  request('/api/greet', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name }),
  });
