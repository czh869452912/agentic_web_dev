import { readFileSync } from 'node:fs';

export const name = 'dsh-browser-compat';
export const inject = ['webServer'];
export const scriptPath = '/__dsh-browser-compat__/compat.js';

export function apply(ctx) {
  const script = readFileSync(new URL('./dist/compat.js', import.meta.url));
  ctx.on('webserver/index-inject', rows => {
    rows.unshift({ kind: 'script-src', placement: 'head', src: scriptPath });
  });
  ctx.effect(() => ctx.webServer.register({
    kind: 'exact',
    path: scriptPath,
    handler(req, res) {
      if (!['GET', 'HEAD'].includes(req.method)) {
        res.writeHead(405, { Allow: 'GET, HEAD' });
        res.end();
        return;
      }
      res.writeHead(200, {
        'Content-Type': 'text/javascript; charset=utf-8',
        'Cache-Control': 'no-cache',
        'X-Content-Type-Options': 'nosniff',
        'Content-Length': script.length,
      });
      res.end(req.method === 'HEAD' ? undefined : script);
    },
  }));
}
