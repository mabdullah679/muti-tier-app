'use strict';

const pino = require('pino');
const { loadConfig } = require('./config');
const { createApp } = require('./app');

const config = loadConfig();
const logger = pino({ level: config.logLevel });
const state = { shuttingDown: false };
const server = createApp({ logger, state }).listen(config.port, () => {
  logger.info({ port: config.port }, 'backend listening');
});

function shutdown(signal) {
  if (state.shuttingDown) return;
  state.shuttingDown = true;
  logger.info({ signal, delayMs: config.shutdownDelayMs }, 'shutdown requested, draining');
  const force = setTimeout(() => {
    logger.error('graceful shutdown timed out, forcing exit');
    process.exit(1);
  }, config.shutdownTimeoutMs);
  force.unref();
  setTimeout(() => {
    server.close((err) => {
      if (err) {
        logger.error({ err }, 'error while closing server');
        process.exit(1);
      }
      logger.info('server closed');
      process.exit(0);
    });
    server.closeIdleConnections();
  }, config.shutdownDelayMs);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('unhandledRejection', (err) => {
  logger.fatal({ err }, 'unhandled rejection');
  process.exit(1);
});
