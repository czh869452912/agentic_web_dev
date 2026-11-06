import { build } from 'esbuild';
import { readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';

await build({
  entryPoints: ['browser.js'],
  outfile: 'dist/compat.js',
  bundle: true,
  format: 'iife',
  platform: 'browser',
  target: 'chrome108',
  minify: true,
  legalComments: 'eof',
});
const script = await readFile('dist/compat.js');
await writeFile('dist/version.json', JSON.stringify({
  version: createHash('sha256').update(script).digest('hex').slice(0, 16),
  coreJs: JSON.parse(await readFile('node_modules/core-js/package.json')).version,
  esbuild: JSON.parse(await readFile('node_modules/esbuild/package.json')).version,
}, null, 2) + '\n');
