import React, { useCallback, useEffect, useState } from 'react';
import { getHealth, greet } from './api';

export default function App() {
  const [health, setHealth] = useState({ state: 'loading' });
  const [name, setName] = useState('');
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  const refresh = useCallback(async () => {
    setHealth({ state: 'loading' });
    try {
      const data = await getHealth();
      setHealth({ state: 'ok', servedBy: data.servedBy, uptime: data.uptimeSeconds });
    } catch (e) {
      setHealth({ state: 'down', message: e.message });
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  async function onSubmit(event) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    setResult(null);
    try {
      setResult(await greet(name));
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="page">
      <h1>Hello, Multi-Tier App!</h1>
      <p className="lede">
        React served by Nginx, talking to a Node API through a Kubernetes ingress.
      </p>

      <section className="card" aria-labelledby="status-heading">
        <h2 id="status-heading">Backend status</h2>
        <p data-testid="health" className={`pill pill-${health.state}`}>
          {health.state === 'loading' && 'Checking...'}
          {health.state === 'ok' && `Backend OK (served by ${health.servedBy})`}
          {health.state === 'down' && `Backend unreachable: ${health.message}`}
        </p>
        <button type="button" onClick={refresh}>
          Re-check
        </button>
      </section>

      <section className="card" aria-labelledby="greet-heading">
        <h2 id="greet-heading">Say hello to the API</h2>
        <form onSubmit={onSubmit}>
          <label htmlFor="name">Your name</label>
          <input
            id="name"
            value={name}
            maxLength={40}
            onChange={(e) => setName(e.target.value)}
            autoComplete="off"
          />
          <button type="submit" disabled={busy}>
            {busy ? 'Sending...' : 'Greet'}
          </button>
        </form>
        {result && (
          <p role="status" className="ok">
            {result.greeting} <small>(pod {result.servedBy})</small>
          </p>
        )}
        {error && (
          <p role="alert" className="err">
            {error}
          </p>
        )}
      </section>
    </main>
  );
}
