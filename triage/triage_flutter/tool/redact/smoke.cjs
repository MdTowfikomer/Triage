const path = require('node:path');
const assert = require('node:assert/strict');
const repo = path.resolve(__dirname, '../../../..');
const { chromium } = require(path.join(repo, '.spike-cache/browser/node_modules/playwright'));
const { makeServer } = require(path.join(repo, 'spike/scripts/serve.cjs'));
const build = path.join(repo, 'triage/triage_flutter/build/web');
const executablePath = process.env.SPIKE_CHROME || path.join(
  process.env.USERPROFILE,
  '.cache/puppeteer/chrome/win64-131.0.6778.204/chrome-win64/chrome.exe',
);

async function main() {
  const server = makeServer(build).listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  const address = server.address();
  const browser = await chromium.launch({ headless: true, executablePath });
  try {
    const page = await browser.newPage();
    page.setDefaultTimeout(180000);
    const requests = [];
    page.on('request', request => requests.push(request.url()));
    page.on('pageerror', error => process.stderr.write(`Browser error: ${error.message}\n`));
    page.on('console', message => {
      if (message.type() === 'error') process.stderr.write(`Browser console: ${message.text()}\n`);
    });
    page.on('response', response => {
      if (response.status() >= 400) process.stderr.write(`Browser asset returned ${response.status()}: ${response.url()}\n`);
    });
    await page.goto(`http://localhost:${address.port}`, { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(() => Boolean(window.triageRedact), { timeout: 30000 });
    const raw = 'Email Anna Kowalski at anna.kowalski@example.com, call +1 415-555-0100, SSN 123-45-6789, card 4111 1111 1111 1111, address 123 Main Street.';
    const result = await page.evaluate(async input => window.triageRedact.redactMany([input]), raw);
    const text = result[0];
    for (const secret of [
      'Anna Kowalski',
      'anna.kowalski@example.com',
      '+1 415-555-0100',
      '123-45-6789',
      '4111 1111 1111 1111',
      '123 Main Street',
    ]) {
      assert.equal(text.includes(secret), false, 'Redact left a test PII value in its result.');
    }
    for (const secret of ['anna.kowalski@example.com', '+1 415-555-0100', '123-45-6789', '4111 1111 1111 1111']) {
      assert.equal(requests.some(url => url.includes(encodeURIComponent(secret))), false, 'Test PII appeared in a network URL.');
    }
    process.stdout.write(`Desert Ant browser redaction passed (${text.length} redacted characters; ${requests.length} asset/model requests).\n`);
  } finally {
    await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
}

main().catch(error => {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
});
