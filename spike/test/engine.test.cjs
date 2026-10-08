const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readWav, validate, SpikeEngine } = require('../web/engine.js');
const tools = require('../assets/tools.json');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function wav(rate = 16000) {
  const data = Buffer.alloc(48);
  data.write('RIFF', 0); data.writeUInt32LE(40, 4); data.write('WAVEfmt ', 8);
  data.writeUInt32LE(16, 16); data.writeUInt16LE(1, 20); data.writeUInt16LE(1, 22);
  data.writeUInt32LE(rate, 24); data.writeUInt32LE(rate * 2, 28);
  data.writeUInt16LE(2, 32); data.writeUInt16LE(16, 34);
  data.write('data', 36); data.writeUInt32LE(4, 40);
  data.writeInt16LE(-32768, 44); data.writeInt16LE(32767, 46);
  return data;
}
test('WAV decoding handles sliced buffers and signed PCM boundaries', () => {
  const padded = Buffer.concat([Buffer.alloc(17), wav(), Buffer.alloc(19)]);
  const samples = readWav(padded.subarray(17, 65));
  assert.deepEqual([...samples], [-1, 32767 / 32768]);
});
test('unsupported or truncated audio is rejected, never mislabeled as 16 kHz', () => {
  assert.throws(() => readWav(wav(48000)), /16 kHz/);
  assert.throws(() => readWav(wav().subarray(0, 46)), /Truncated/);
});
test('suppressed calls cannot become actionable through schema validation', () => {
  const candidate = { name: 'add_shopping_item', arguments: { item: 'milk', quantity: '', store: '' } };
  assert.equal(validate({ function_calls: [], suppressed_calls: [candidate], confidence: 0.01 }, tools).valid, false);
  assert.equal(validate({ function_calls: [candidate] }, tools).valid, true);
  assert.equal(validate({ function_calls: [candidate], validation: { ungrounded: ['add_shopping_item.item'] } }, tools).valid, false);
  assert.equal(validate({ function_calls: [{ name: 'delete_all', arguments: {} }] }, tools).valid, false);
});
test('invalid PCM fails before reaching native inference', () => {
  const engine = new SpikeEngine({ _malloc: () => 16 }, tools);
  assert.throws(() => engine.transcribe(new Float32Array()), /0–30 seconds/);
  assert.throws(() => engine.transcribe(new Float32Array(480001)), /0–30 seconds/);
  assert.throws(() => engine.transcribe(new Float32Array([NaN])), /finite/);
  assert.throws(() => engine.transcribe(new Float32Array([1.1])), /finite/);
  assert.equal(engine.route('  ').skipped, true);
});
test('fixture identifier cannot overwrite the worker request identifier', async () => {
  const messages = [];
  class FakeWorker {
    postMessage(message) {
      messages.push(message);
      queueMicrotask(() => this.onmessage({ data: { requestId: message.requestId, result: { action: message.action, fixture: message.id } } }));
    }
    terminate() {}
  }
  const window = { addEventListener() {} };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../web/bridge.js'), 'utf8'), { window, Worker: FakeWorker });
  await window.triageSpike(JSON.stringify({ action: 'init' }));
  const result = JSON.parse(await window.triageSpike(JSON.stringify({ action: 'fixture', id: '01' })));
  assert.equal(result.fixture, '01');
  assert.equal(messages[1].id, '01');
  assert.equal(messages[1].requestId, 2);
});
test('frequency metering stays local and cancel releases capture without inference', async () => {
  let stops = 0, closes = 0;
  const messages = [];
  class Worker {
    postMessage(message) {
      messages.push(message);
      queueMicrotask(() => this.onmessage({ data: { requestId: message.requestId, result: {} } }));
    }
    terminate() {}
  }
  const node = () => ({ connect() {}, disconnect() {} });
  class AudioContext {
    constructor() { this.sampleRate = 48000; this.destination = {}; }
    async resume() {}
    async close() { closes++; }
    createMediaStreamSource() { return node(); }
    createScriptProcessor() { return node(); }
    createGain() { return { ...node(), gain: {} }; }
    createAnalyser() { return { ...node(), frequencyBinCount: 128, getByteFrequencyData(bins) { bins.fill(128); } }; }
  }
  const window = { isSecureContext: true, addEventListener() {} };
  const navigator = { mediaDevices: { async getUserMedia() { return { getTracks: () => [{ stop() { stops++; } }] }; } } };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../web/bridge.js'), 'utf8'), { window, navigator, Worker, AudioContext });
  const invoke = async action => JSON.parse(await window.triageSpike(JSON.stringify({ action })));
  await invoke('init'); await invoke('start');
  assert.equal((await invoke('levels')).levels.length, 12);
  assert.ok((await invoke('levels')).levels.every(level => level > 0));
  await invoke('cancel');
  assert.equal(stops, 1); assert.equal(closes, 1);
  assert.ok((await invoke('levels')).levels.every(level => level === 0));
  assert.deepEqual(messages.map(message => message.action), ['init']);
});
