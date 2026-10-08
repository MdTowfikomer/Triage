const path = require('node:path');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const repo = path.resolve(__dirname, '../../..');
const { chromium } = require(path.join(repo, '.spike-cache/browser/node_modules/playwright'));
const { makeServer } = require(path.join(repo, 'spike/scripts/serve.cjs'));
const app = path.resolve(__dirname, '..');
const assets = path.join(app, 'assets/voice_engine');
const fixture = path.join(repo, 'spike/assets/audio/01.wav');
const executablePath = process.env.SPIKE_CHROME || path.join(
  process.env.USERPROFILE,
  '.cache/puppeteer/chrome/win64-131.0.6778.204/chrome-win64/chrome.exe',
);

async function main() {
  if (!fs.existsSync(path.join(assets, 'models/needle3.cact'))) {
    throw new Error('Run tool/prepare_android_voice.ps1 before this smoke test.');
  }
  const server = makeServer(assets).listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  let browser;
  try {
    browser = await chromium.launch({ headless: true, executablePath });
    const page = await browser.newPage();
    page.setDefaultTimeout(180000);
    await page.addInitScript(() => {
      window.voiceResponses = [];
      window.TriageVoice = { postMessage: message => window.voiceResponses.push(JSON.parse(message)) };
    });
    page.on('pageerror', error => process.stderr.write(`Browser error: ${error.message}\n`));
    page.on('response', response => {
      if (response.status() >= 400) process.stderr.write(`Asset ${response.status()}: ${response.url()}\n`);
    });
    await page.goto(`http://localhost:${server.address().port}/index.html`);
    await page.evaluate(() => window.triageNeedleReceive(JSON.stringify({ requestId: 'init', action: 'init' })));
    const initialized = await page.waitForFunction(() => window.voiceResponses.find(item => item.requestId === 'init'));
    const initResult = await initialized.jsonValue();
    assert.ok(initResult.result?.prefix_tokens > 0, 'The bundled worker did not initialize Needle.');

    await page.evaluate(() => window.triageNeedleReceive(JSON.stringify({
      requestId: 'text', action: 'text', text: 'Remind me to call the dentist tomorrow at 3pm',
    })));
    const routed = await page.waitForFunction(() => window.voiceResponses.find(item => item.requestId === 'text'));
    const textResult = (await routed.jsonValue()).result;
    assert.equal(textResult.routing?.parsed?.function_calls?.[0]?.name, 'add_reminder');

    const wav = fs.readFileSync(fixture);
    const dataTag = wav.indexOf(Buffer.from('data'));
    assert.ok(dataTag >= 0, 'Audio fixture has no PCM data chunk.');
    const pcm16Base64 = wav.subarray(dataTag + 8, dataTag + 8 + wav.readUInt32LE(dataTag + 4)).toString('base64');
    await page.evaluate(encoded => window.triageNeedleReceive(JSON.stringify({
      requestId: 'audio', action: 'audio', pcm16Base64: encoded,
    })), pcm16Base64);
    const audio = await page.waitForFunction(() => window.voiceResponses.find(item => item.requestId === 'audio'));
    const audioResult = (await audio.jsonValue()).result;
    assert.ok(audioResult.transcript?.length > 0, 'Whistle returned an empty transcript for the fixture.');
    assert.ok(audioResult.routing, 'Needle did not route the Whistle transcript.');
    process.stdout.write(`Android WebView bridge smoke passed: ${audioResult.transcript}\n`);
  } finally {
    await browser?.close();
    await new Promise(resolve => server.close(resolve));
  }
}

main().catch(error => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
