const { test, expect } = require('@playwright/test');

test('built site loads and renders data fetched from /api (wrangler pages dev)', async ({ page }) => {
  const apiCalls = [];
  page.on('response', (r) => {
    if (new URL(r.url()).pathname.startsWith('/api/')) apiCalls.push(`${r.request().method()} ${new URL(r.url()).pathname} ${r.status()}`);
  });

  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'Hello, Multi-Tier App!' })).toBeVisible();
  await expect(page.getByTestId('health')).toHaveText('Backend OK (served by cloudflare-pages)');

  await page.getByLabel('Your name').fill('Ada Lovelace');
  await page.getByRole('button', { name: 'Greet' }).click();
  await expect(page.getByRole('status')).toContainText('Hello, Ada Lovelace!');
  await expect(page.getByRole('status')).toContainText('cloudflare-pages');

  await page.getByLabel('Your name').fill('<script>');
  await page.getByRole('button', { name: 'Greet' }).click();
  await expect(page.getByRole('alert')).toContainText('may only contain letters');

  expect(apiCalls).toEqual(['GET /api/health 200', 'POST /api/greet 200', 'POST /api/greet 400']);
  await page.screenshot({ path: 'test-results/pages-site.png', fullPage: true });
});
