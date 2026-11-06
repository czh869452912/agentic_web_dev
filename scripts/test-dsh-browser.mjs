// Run inside an isolated QA container with DSH + code-server + HTTPS gateway.
// Install Playwright outside the production image; see configs/browser-compat/README.md.
import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const log = await readFile(process.env.DSH_TEST_LOG || '/tmp/dsh-smoke.log', 'utf8');
const launchUrl = log.match(/https:\/\/3080\.localhost:8443\/\?[^\s\u001b]+/)?.[0];
assert.ok(launchUrl, 'DSH launch URL missing');
const browser = await chromium.launch({
  executablePath: process.env.DSH_TEST_BROWSER || undefined,
  args: ['--no-sandbox', `--host-resolver-rules=MAP 3080.localhost ${process.env.DSH_TEST_GATEWAY_IP}`],
});
try {
  const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1360, height: 900 } });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(launchUrl);
  if (new URL(page.url()).pathname.startsWith('/login')) {
    await page.fill('input[type="password"]', process.env.PASSWORD);
    await Promise.all([page.waitForNavigation(), page.click('button[type="submit"], input[type="submit"]')]);
  }
  await page.waitForFunction(() => globalThis.__DSH_BROWSER_COMPAT__, null, { timeout: 30000 });
  await page.waitForSelector('button', { timeout: 30000 });
  const state = await page.evaluate(() => ({
    injected: globalThis.__DSH_BROWSER_COMPAT__,
    apis: [typeof Promise.withResolvers, typeof AbortSignal.any, typeof [].toSorted, typeof URL.parse],
    body: document.body.innerText.slice(0, 1200),
    buttons: [...document.querySelectorAll('button')].map(b => b.innerText || b.getAttribute('aria-label')).filter(Boolean),
  }));
  assert.ok(state.apis.every(value => value === 'function'));
  const office = await page.evaluate(async () => {
    const status = await fetch('/univer-api/status');
    const start = await fetch('/univer-api/gateway/start', { method: 'POST' });
    const started = await start.json();
    return { status: status.status, start: start.status, started };
  });
  assert.equal(office.status, 200);
  assert.equal(office.start, 200);
  assert.equal(office.started.ok, true);
  const session = await page.evaluate(async () => {
    const endpoint = 'session/create';
    const response = await fetch('/api/' + endpoint, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ type: 'client-request', rpcId: crypto.randomUUID(), method: endpoint, payload: { args: { request: { cwd: '/workspace' } } } }),
    });
    return response.json();
  });
  assert.equal(session.result.ok, true, JSON.stringify(session.result));
  const fixture = await page.evaluate(async () => {
    const file = '/workspace/compat-' + crypto.randomUUID() + '.univer';
    const key = btoa(file).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
    const options = { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' };
    const create = await fetch('/uf/' + key, options);
    const unit = await fetch('/uf/' + key + '/universer-api/snapshot/2/unit/-/create', {
      ...options, body: JSON.stringify({ name: 'Compatibility smoke' }),
    });
    return { file, key, create: create.status, unit: unit.status, result: await unit.json() };
  });
  assert.ok([200, 201].includes(fixture.create), JSON.stringify(fixture));
  assert.ok([200, 201].includes(fixture.unit), JSON.stringify(fixture));
  const viewer = await page.evaluate(async () => {
    const unauthenticatedDocument = await fetch('/univer-viewer/');
    return { documentStatus: unauthenticatedDocument.status };
  });
  // Document access still requires a session and file; forwarding must not bypass that gate.
  assert.ok([400, 403].includes(viewer.documentStatus));
  let viewerPage = await context.newPage();
  viewerPage.on('pageerror', error => errors.push('Viewer: ' + error.message));
  const response = await viewerPage.goto('https://3080.localhost:8443/univer-viewer/?' + new URLSearchParams({
    file: fixture.key, sessionId: session.result.value.sessionId,
  }));
  assert.equal(response.status(), 200);
  await viewerPage.waitForFunction(() => globalThis.__DSH_BROWSER_COMPAT__);
  try {
    await viewerPage.waitForSelector('canvas', { timeout: 30000 });
    await viewerPage.waitForSelector('text=Insert', { state: 'visible', timeout: 30000 });
  } catch (error) {
    console.log(JSON.stringify({ viewerErrors: errors, viewerBody: await viewerPage.locator('body').innerText() }));
    throw error;
  }
  viewer.rendered = true;
  const waitForSheet = () => viewerPage.waitForFunction(() => ![...document.querySelectorAll('[class*="skeleton"], [class*="pulse"]')]
    .some(e => e.getBoundingClientRect().width && getComputedStyle(e).visibility !== 'hidden'), null, { timeout: 30000 });
  await waitForSheet();
  await context.grantPermissions(['clipboard-read', 'clipboard-write']);
  const marker = 'compat-' + browser.version();
  // A1 at the fixed QA viewport; exercise real keyboard editing and collaboration persistence.
  await viewerPage.mouse.dblclick(340, 210);
  await viewerPage.keyboard.type(marker);
  await viewerPage.keyboard.press('Enter');
  await viewerPage.waitForTimeout(2000);
  // A fresh browser context rules out the editor's local persistence cache.
  const fresh = await browser.newContext({
    ignoreHTTPSErrors: true, viewport: { width: 1360, height: 900 },
    storageState: { cookies: await context.cookies(), origins: [] },
  });
  const viewerUrl = viewerPage.url();
  await viewerPage.close();
  viewerPage = await fresh.newPage();
  viewerPage.on('pageerror', error => errors.push('Viewer reload: ' + error.message));
  await viewerPage.goto(viewerUrl);
  await viewerPage.reload();
  await viewerPage.waitForSelector('text=Insert', { state: 'visible' });
  await waitForSheet();
  await fresh.grantPermissions(['clipboard-read', 'clipboard-write']);
  await viewerPage.evaluate(() => navigator.clipboard.writeText(''));
  await viewerPage.mouse.click(340, 210);
  await viewerPage.keyboard.press('Control+c');
  await viewerPage.waitForFunction(expected => navigator.clipboard.readText().then(value => value.includes(expected)), marker);
  viewer.editSurvivedReload = true;
  viewer.editReadInFreshContext = true;
  await viewerPage.keyboard.press('Escape');
  await viewerPage.waitForTimeout(250);
  viewer.body = (await viewerPage.locator('body').innerText()).slice(0, 500);
  await viewerPage.screenshot({ path: (process.env.DSH_TEST_SCREENSHOT || '/tmp/dsh-smoke.png').replace('.png', '-viewer.png') });
  await page.screenshot({ path: process.env.DSH_TEST_SCREENSHOT || '/tmp/dsh-smoke.png', fullPage: true });
  console.log(JSON.stringify({ browser: browser.version(), state, office, viewer, errors }, null, 2));
  assert.deepEqual(errors, []);
  await fresh.close();
  await context.close();
} catch (error) {
  throw new Error(String(error.message).replaceAll(launchUrl, '[DSH login URL]'));
} finally {
  await browser.close();
}
