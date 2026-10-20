'use strict';

function intFromEnv(name, fallback, { min = 0, max = 65535 } = {}) {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new Error(`Invalid ${name}: "${raw}" (expected integer ${min}-${max})`);
  }
  return value;
}

function loadConfig() {
  return {
    port: intFromEnv('PORT', 3001, { min: 1 }),
    logLevel: process.env.LOG_LEVEL || 'info',
    // Time to keep serving (but report not-ready) after SIGTERM so the
    // endpoint controller can remove the pod from the Service first.
    shutdownDelayMs: intFromEnv('SHUTDOWN_DELAY_MS', 5000, { max: 60000 }),
    // Hard cap on how long graceful shutdown may take before we force exit.
    shutdownTimeoutMs: intFromEnv('SHUTDOWN_TIMEOUT_MS', 15000, { max: 120000 }),
  };
}

module.exports = { loadConfig };
