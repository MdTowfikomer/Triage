const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('../../../.spike-cache/browser/node_modules/playwright');
const { makeServer } = require('../../../spike/scripts/serve.cjs');
const repo = path.resolve(__dirname, '../../..');
const output = path.join(repo, 'docs/ui');
const build = process.env.UI_BUILD || path.resolve(__dirname, '../build/web');
const authOnly = process.env.UI_AUTH_ONLY === 'true';
async function main() {
  const server = makeServer(build);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let browser, page;
  try {
    browser = await chromium.launch({
      executablePath: process.env.SPIKE_CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe',
      headless: true, timeout: 30000,
      args: ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream',
        `--use-file-for-fake-audio-capture=${path.join(repo, 'spike/assets/audio/01.wav')}`],
    });
    const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    const errors = [], external = [];
    context.on('request', request => {
      if (!request.url().startsWith('http://localhost:') && !request.url().startsWith('blob:') && !request.url().startsWith('data:')) external.push(request.url());
    });
    page = await context.newPage();
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
    await page.goto(`http://localhost:${server.address().port}/`, { waitUntil: 'networkidle' });
    await page.locator('flutter-view').waitFor({ state: 'attached' });
    const enable = page.locator('flt-semantics-placeholder');
    await enable.waitFor({state:'attached'});
    await enable.evaluate(element => element.click());
    fs.mkdirSync(output, { recursive: true });
    if (authOnly) {
      await page.getByRole('button', { name: 'Sign in', exact: true }).waitFor();
      await page.screenshot({ path: path.join(output, 'auth-desktop.png') });
      await page.getByRole('button', { name: 'New here? Create an account', exact: true }).click();
      await page.getByRole('button', { name: 'Create account', exact: true }).waitFor();
      await page.setViewportSize({ width: 320, height: 700 });
      await page.screenshot({ path: path.join(output, 'auth-mobile.png') });
    } else {
      await page.locator('[aria-label*="Ship the new onboarding"]').first().waitFor();
      await page.screenshot({ path: path.join(output, 'inbox-desktop.png') });
      await page.setViewportSize({ width: 390, height: 844 });
      await page.screenshot({ path: path.join(output, 'inbox-mobile.png') });
      await page.setViewportSize({ width: 320, height: 700 });
      await page.screenshot({ path: path.join(output, 'inbox-narrow.png') });
      await page.setViewportSize({ width: 1280, height: 900 });
      console.log('Preparing actual Needle/Whistle via Flutter voice control');
      await page.getByRole('button', { name: 'Tap to speak', exact: true }).click();
      await page.getByRole('button', { name: /Finish recording/ }).waitFor({ timeout: 90000 });
      await page.waitForTimeout(4800);
      const levels = JSON.parse(await page.evaluate(() => window.triageSpike(JSON.stringify({ action: 'levels' }))));
      assert.equal(levels.levels.length, 12);
      await page.screenshot({ path: path.join(output, 'voice-recording.png') });
      await page.getByRole('button', { name: /Finish recording/ }).click();
      await page.getByText('Ready for your inbox', { exact: true }).waitFor({ timeout: 90000 });
      await page.screenshot({ path: path.join(output, 'voice-confirmation.png') });
      await page.getByRole('button', { name: /Edit/, exact: true }).click();
      await page.getByText('Review / Edit required', { exact: true }).waitFor();
      await page.waitForTimeout(3500);
      await page.screenshot({ path: path.join(output, 'voice-review.png') });
      await page.getByRole('button', { name: 'Save Now', exact: true }).click();
      await page.getByRole('button', { name: 'Tap to speak', exact: true }).waitFor();
      const storage = await page.evaluate(() => Object.fromEntries(Object.entries(localStorage).filter(([key]) => key.includes('triage.v1.demo.raw'))));
      assert.ok(Object.values(storage).some(raw => raw.includes('dentist')));
      console.log('Actual microphone pipeline saved a device-local demo reminder');
      await context.setOffline(true);
      const routed = JSON.parse(await page.evaluate(() => window.triageSpike(JSON.stringify({ action: 'text', text: 'Buy eggs, milk, and bread from Whole Foods' }))));
      assert.equal(routed.routing.parsed.function_calls.length, 0);
      await context.setOffline(false);
      await page.getByRole('button', { name: /Type a thought/ }).click();
      const field = page.getByRole('textbox').first();
      await field.fill('Buy eggs, milk, and bread from Whole Foods');
      await page.getByRole('button', { name: 'Capture', exact: true }).click();
      await page.getByText('Review / Edit required', { exact: true }).waitFor({ timeout: 90000 });
      await page.screenshot({ path: path.join(output, 'voice-suppressed.png') });
      await page.getByRole('button', { name: 'Cancel', exact: true }).click();
      await page.getByRole('button', { name: 'Tap to speak', exact: true }).waitFor();
    }
    assert.deepEqual(errors, []);
    assert.deepEqual(external, []);
    const evidence = { recordedAt: new Date().toISOString(), browser: browser.version(), authOnly,
      screenshots: true, fakeMicrophone: !authOnly, externalRequests: external, errors,
      liveBackend: false, note: 'Demo repository for visual/voice checks. Production auth visual-only; backend test suite verifies server operations.' };
    fs.writeFileSync(path.join(output, authOnly ? 'auth-check.json' : 'browser-check.json'), JSON.stringify(evidence, null, 2) + '\n');
    console.log('Browser UI checks passed. No external font/CDN requests.');
  } catch (error) {
    if (page) {
      fs.mkdirSync(output, { recursive: true });
      await page.screenshot({ path: path.join(output, 'check-failure.png') });
      console.log('Visible semantics:', await page.locator('body').innerText());
    }
    throw error;
  } finally {
    if (browser) await browser.close();
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
