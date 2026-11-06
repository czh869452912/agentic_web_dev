import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, writeFile, rm, link } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import vm from 'node:vm';
import { installAbortSignalAny } from '../signal-any.js';
import { prepareViewer } from '../prepare-viewer.mjs';
import { proxyDomain, publicUrl } from '../forwarding.mjs';

test('forwarding shares the same domain, custom port and normalized HTTPS authority', () => {
  assert.equal(publicUrl('', {}), 'https://3080.localhost:8443/');
  assert.equal(publicUrl('', { GATEWAY_PORT: '9443' }), 'https://3080.localhost:9443/');
  const env = { CODE_SERVER_PROXY_DOMAIN: '{{port}}.dev.example:443' };
  assert.equal(proxyDomain(env), '{{port}}.dev.example');
  assert.equal(publicUrl('', env), 'https://3080.dev.example/');
  assert.equal(publicUrl('', { CODE_SERVER_PROXY_DOMAIN: 'dev.example:8443' }), 'https://3080.dev.example:8443/');
  assert.throws(() => publicUrl('https://dev.example:8443/', env), /must match/);
  assert.throws(() => publicUrl('https://3080.dev.example/proxy/3080/', env), /root URL/);
  assert.throws(() => publicUrl('http://3080.dev.example/', env), /HTTPS/);
});

test('AbortSignal.any: native preservation, validation, reason, first abort and listener cleanup', () => {
  const native = Object.getOwnPropertyDescriptor(AbortSignal, 'any');
  installAbortSignalAny();
  assert.equal(AbortSignal.any, native.value);
  delete AbortSignal.any;
  try {
    installAbortSignalAny();
    assert.equal(AbortSignal.any([]).aborted, false);
    assert.throws(() => AbortSignal.any(null), TypeError);
    assert.throws(() => AbortSignal.any([{}]), TypeError);
    const done = AbortSignal.abort('already finished');
    assert.equal(AbortSignal.any([done]).reason, 'already finished');
    assert.throws(() => AbortSignal.any([done, {}]), TypeError);
    const a = new AbortController();
    const b = new AbortController();
    let added = 0;
    let removed = 0;
    for (const source of [a.signal, b.signal]) {
      const add = source.addEventListener.bind(source);
      const remove = source.removeEventListener.bind(source);
      source.addEventListener = (...args) => { added++; return add(...args); };
      source.removeEventListener = (...args) => { removed++; return remove(...args); };
    }
    const combined = AbortSignal.any([a.signal, a.signal, b.signal]);
    assert.equal(added, 2);
    let events = 0;
    combined.addEventListener('abort', () => events++);
    const reason = new Error('cancel requested');
    b.abort(reason);
    a.abort('later');
    assert.equal(combined.reason, reason);
    assert.equal(events, 1);
    assert.equal(removed, 2);
    assert.deepEqual(Object.keys(combined), []);
  } finally {
    Object.defineProperty(AbortSignal, 'any', native);
  }
});

test('browser bundle supplies missing APIs and preserves sort semantics', async () => {
  const context = vm.createContext({ AbortSignal, AbortController, URL, URLSearchParams });
  vm.runInContext('delete Promise.withResolvers; delete Array.prototype.toSorted', context);
  vm.runInContext(await readFile(new URL('../dist/compat.js', import.meta.url), 'utf8'), context);
  assert.equal(await vm.runInContext(`(async () => {
    const deferred = Promise.withResolvers();
    deferred.resolve(42);
    const original = [{k: 1, id: 'a'}, {k: 0, id: 'b'}, {k: 1, id: 'c'}];
    const sorted = original.toSorted((a,b) => a.k-b.k);
    if (sorted.map(x => x.id).join('') !== 'bac' || original[0].id !== 'a') return false;
    const sparse = [, 1].toSorted();
    if (!(1 in sparse) || sparse[1] !== undefined) return false;
    return await deferred.promise === 42 && URL.canParse('/a', 'https://example.test') &&
      URL.parse('http://[') === null && __DSH_BROWSER_COMPAT__.version === 1;
  })()`, context), true);
});

test('Viewer early injection is idempotent, reversible and survives a package upgrade', async () => {
  const profile = await mkdtemp(join(tmpdir(), 'dsh-compat-'));
  try {
    const pkg = join(profile, 'node_modules/dsh-univer-office');
    await mkdir(join(pkg, 'artifacts/viewer'), { recursive: true });
    await writeFile(join(profile, 'package.json'), '{}');
    await writeFile(join(pkg, 'package.json'), '{"name":"dsh-univer-office"}');
    const file = join(pkg, 'artifacts/viewer/index.html');
    const source = '<html><head><script type="module" src="/univer-viewer/main.js"></script></head></html>';
    await writeFile(file, source);
    const storeFile = join(profile, 'upstream-store-index.html');
    await link(file, storeFile);
    await prepareViewer(profile);
    assert.equal(await readFile(storeFile, 'utf8'), source, 'upstream hard-linked store must stay unchanged');
    const first = await readFile(file, 'utf8');
    await prepareViewer(profile);
    assert.equal(await readFile(file, 'utf8'), first);
    assert.ok(first.indexOf('compat.js') < first.indexOf('type="module"'));
    await writeFile(file, source.replace('main.js', 'upgraded.js'));
    await prepareViewer(profile);
    assert.match(await readFile(file, 'utf8'), /compat.js.*<\/script>/);
    await prepareViewer(profile, false);
    assert.doesNotMatch(await readFile(file, 'utf8'), /dsh-browser-compat/);
    assert.match(await readFile(file, 'utf8'), /upgraded.js/);
  } finally {
    await rm(profile, { recursive: true, force: true });
  }
});
