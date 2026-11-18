// Finishes the Pages output after `react-scripts build`: adds _routes.json so
// only /api/* invokes the Function (static assets stay free and unmetered).
import { copyFileSync, existsSync } from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const out = path.join(root, 'frontend/build');
if (!existsSync(path.join(out, 'index.html'))) {
  console.error('frontend/build/index.html missing: run the React build first');
  process.exit(1);
}
copyFileSync(path.join(root, 'pages/_routes.json'), path.join(out, '_routes.json'));
console.log('Pages output ready in frontend/build');
