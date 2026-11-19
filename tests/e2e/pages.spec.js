const { test, expect } = require('@playwright/test');

test('built site loads and renders data fetched from /api (wrangler pages dev)', async ({ page }) => {
  const apiCalls = [];
  page.on('response', (r) => {
    if (new URL(r.url()).pathname.startsWith('/api/')) apiCalls.push(`${r.request().method()} ${new URL(r.url()).pathname} ${r.status()}`);
  });

  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'Hello, Multi-Tier App!' })).toBeVisible();
  await expect(page.getByTestId('health')).toHaveText('Backend OK (served by cloudflare-pages)');
  // The subtitle must be true on every deployment (EKS and Pages), so it may not name Nginx or Kubernetes.
  await expect(page.getByText('A React front end talking to a small Node API.')).toBeVisible();
  await expect(page.locator('body')).not.toContainText(/Nginx|Kubernetes/i);

  await page.getByLabel('Your name').fill('Ada Lovelace');
  await page.getByRole('button', { name: 'Greet' }).click();
  await expect(page.getByRole('status')).toContainText('Hello, Ada Lovelace!');
  await expect(page.getByRole('status')).toContainText('cloudflare-pages');
  await expect(page.getByTestId('greet-result')).toContainText('Answered by the API on: cloudflare-pages');
  await expect(page.getByTestId('demonstrates')).toContainText('What this demonstrates');

  await page.getByLabel('Your name').fill('<script>');
  await page.getByRole('button', { name: 'Greet' }).click();
  await expect(page.getByRole('alert')).toContainText('may only contain letters');

  expect(apiCalls).toEqual(['GET /api/health 200', 'POST /api/greet 200', 'POST /api/greet 400']);
  await page.screenshot({ path: 'test-results/pages-site.png', fullPage: true });
});
