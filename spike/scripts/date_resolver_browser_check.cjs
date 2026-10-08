// Compile tool/date_resolver_portability.dart first (see docs/DATE_RESOLVER.md).
const path = require('node:path');
const fs = require('node:fs');
const { chromium } = require('../../.spike-cache/browser/node_modules/playwright');
async function main() {
  const browser = await chromium.launch({
    executablePath: process.env.SPIKE_CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    headless: true, timeout: 30000,
  });
  const rows = [];
  try {
    for (const zone of ['UTC', 'Asia/Kolkata', 'America/New_York', 'Australia/Lord_Howe', 'Pacific/Apia']) {
      const context = await browser.newContext({ timezoneId: zone });
      try {
        const page = await context.newPage();
        await page.setContent('<!doctype html><title>Date resolver portability checks</title>');
        await page.evaluate(zone => { window.resolverTestZone = zone; }, zone);
        await page.addScriptTag({ path: path.resolve(__dirname, '../../.spike-cache/date-resolver/portability.js') });
        const row = await page.evaluate(() => JSON.parse(window.resolverTestResults));
        rows.push(row);
        console.log(`${zone}: ${row.passed} checks passed`);
      } finally { await context.close(); }
    }
    const target = path.resolve(__dirname, '../../docs/spike/date_resolver_timezones.json');
    fs.writeFileSync(target, JSON.stringify({ browser: browser.version(), rows, total_passed: rows.reduce((total, row) => total + row.passed, 0) }, null, 2) + '\n');
  } finally { await browser.close(); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
