const { defineConfig } = require('@playwright/test');

// Serves the built site with `wrangler pages dev` (local only, no Cloudflare login).
module.exports = defineConfig({
  testDir: 'tests/e2e',
  timeout: 60000,
  use: { baseURL: 'http://127.0.0.1:8788' },
  webServer: {
    command: 'npx wrangler pages dev --port 8788 --ip 127.0.0.1',
    url: 'http://127.0.0.1:8788/api/health',
    timeout: 120000,
    reuseExistingServer: false,
    env: { WRANGLER_SEND_METRICS: 'false', CI: '1' },
  },
});
