import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export function proxyDomain(env = process.env) {
  let pattern = env.CODE_SERVER_PROXY_DOMAIN?.trim() || `{{port}}.localhost:${env.GATEWAY_PORT || 8443}`;
  if (!pattern.includes('{{port}}')) pattern = '{{port}}.' + pattern;
  const sample = pattern.replaceAll('{{port}}', '3080');
  const url = new URL('https://' + sample);
  if (url.username || url.password || url.pathname !== '/' || url.search || url.hash || /[{}\/]/.test(sample)) {
    throw new Error('CODE_SERVER_PROXY_DOMAIN must be a hostname pattern, e.g. {{port}}.dev.example:8443');
  }
  // Browsers omit the default HTTPS port from Host, which code-server matches literally.
  return pattern.toLowerCase().replace(/:443$/, '');
}

export function publicUrl(value, env = process.env) {
  const expected = new URL('https://' + proxyDomain(env).replaceAll('{{port}}', '3080'));
  const url = new URL(value || expected.href);
  if (url.protocol !== 'https:' || url.username || url.password || url.pathname !== '/' || url.search || url.hash) {
    throw new Error('Expected the forwarding HTTPS root URL, e.g. https://3080.dev.example:8443/');
  }
  if (url.host !== expected.host) throw new Error('URL must match CODE_SERVER_PROXY_DOMAIN: ' + expected.origin);
  return url.href;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  console.log(process.argv[2] === 'domain' ? proxyDomain() : publicUrl(process.argv[3]));
}
