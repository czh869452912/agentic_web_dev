import { readFile, writeFile, rename, rm } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { scriptPath } from './host.mjs';

export async function prepareViewer(profile, enabled = true) {
  const require = createRequire(pathToFileURL(join(resolve(profile), 'package.json')));
  const officeRoot = dirname(require.resolve('dsh-univer-office/package.json'));
  const path = join(officeRoot, 'artifacts/viewer/index.html');
  const original = await readFile(path, 'utf8');
  const clean = original.replace(/\s*<!-- dsh-browser-compat -->\s*<script\b[^>]*><\/script>\s*/g, '');
  if (!/<head(?:\s[^>]*)?>/i.test(clean)) throw new Error('Office Viewer has no <head>; compatibility injection stopped');
  const html = enabled ? clean.replace(/<head(?:\s[^>]*)?>/i,
    head => `${head}\n    <!-- dsh-browser-compat --><script src="${scriptPath}"></script>\n    `) : clean;
  if (html !== original) {
    // pnpm can hard-link installed files to its store: replace this directory
    // entry atomically instead of writing through the shared upstream inode.
    const temporary = `${path}.compat-${process.pid}`;
    try {
      await writeFile(temporary, html, { flag: 'wx' });
      await rename(temporary, path);
    } finally {
      await rm(temporary, { force: true });
    }
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  await prepareViewer(process.argv[2], process.env.DSH_BROWSER_COMPAT !== '0');
}
