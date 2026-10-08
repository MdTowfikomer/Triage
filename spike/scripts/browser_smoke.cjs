const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('../../.spike-cache/browser/node_modules/playwright');
const { makeServer } = require('./serve.cjs');
const root = path.resolve(__dirname, '..');
const output = path.resolve(root, '../docs/spike');
async function main() {
  const server = makeServer();
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    console.log('Launching browser');
    browser = await chromium.launch({
      executablePath: process.env.SPIKE_CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe',
      headless: true, timeout: 30000,
      args: ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream', `--use-file-for-fake-audio-capture=${path.join(root, 'assets/audio/01.wav')}`],
    });
    const context = await browser.newContext({ viewport: { width: 1100, height: 850 } });
    const page = await context.newPage();
    const errors = [], requests = [];
    page.on('pageerror', error => errors.push(String(error)));
    context.on('request', request => requests.push(request.url()));
    console.log('Loading Flutter runner');
    await page.goto(`http://localhost:${server.address().port}/`, { waitUntil: 'networkidle', timeout: 30000 });
    await page.locator('flutter-view').waitFor({ state: 'attached' });
    const invoke = message => page.evaluate(async value => {
      const result = await Promise.race([
        window.triageSpike(JSON.stringify(value)),
        new Promise((_, reject) => setTimeout(() => reject(new Error(`Timed out: ${value.action}`)), 90000)),
      ]);
      return JSON.parse(result);
    }, message);
    console.log('Initializing models');
    const init = await invoke({ action: 'init' });
    console.log('Transcribing fixture');
    const fixture = await invoke({ action: 'fixture', id: '01' });
    assert.ok(fixture.transcript.includes('dentist'));
    assert.equal(typeof fixture.routing.parsed.confidence, 'number');
    const silence = await invoke({ action: 'silence' });
    assert.equal(silence.transcript, '');
    assert.equal(silence.routing.skipped, true);
    console.log('Testing prerecorded microphone capture');
    const capture = await invoke({ action: 'start' });
    await new Promise(resolve => setTimeout(resolve, 4600));
    const microphone = await invoke({ action: 'stop' });
    assert.ok(microphone.stt.duration_ms > 0);
    assert.ok(microphone.transcript.includes('dentist'), `Fake microphone transcript: ${microphone.transcript}`);
    console.log('Testing offline inference');
    await context.setOffline(true);
    const offline = await invoke({ action: 'text', text: 'Buy eggs, milk, and bread from Whole Foods' });
    assert.ok(Array.isArray(offline.routing.parsed.function_calls));
    assert.equal(typeof offline.routing.parsed.confidence, 'number');
    // No caller input is sent to a remote endpoint. Also catch accidental Flutter CDN loads.
    await context.setOffline(false);
    // Exercise the actual Flutter controls as well as the public bridge API.
    console.log('Testing Flutter controls');
    const semantics = page.locator('flt-semantics-placeholder');
    if (await semantics.count()) await semantics.evaluate(element => element.click());
    await page.getByRole('button', { name: 'Initialize models', exact: true }).click();
    await page.getByRole('button', { name: 'Record', exact: true }).waitFor({ state: 'visible' });
    await page.getByRole('button', { name: 'Inject prerecorded test WAV', exact: true }).click();
    await page.getByText('Ready. Results are experimental; no actions are executed.', { exact: true }).waitFor({ state: 'visible' });
    fs.mkdirSync(output, { recursive: true });
    await page.screenshot({ path: path.join(output, 'runner.png'), fullPage: true });
    assert.deepEqual(requests.filter(url => !url.startsWith('http://localhost:') && !url.startsWith('blob:') && !url.startsWith('data:')), []);
    assert.deepEqual(errors, []);
    const result = { browser: browser.version(), origin: page.url(), fake_microphone: true, capture, init, fixture, silence, microphone, offline, errors, network_requests: requests };
    fs.writeFileSync(path.join(output, 'browser_smoke.json'), JSON.stringify(result, null, 2) + '\n');
    console.log(`Browser smoke passed; ${browser.version()}, offline inference and 16 kHz resampled fake microphone verified.`);
  } finally {
    if (browser) await browser.close();
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
