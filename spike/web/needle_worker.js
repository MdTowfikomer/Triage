'use strict';
importScripts('vendor/needle.js', 'engine.js');
let engine;
let sequence = Promise.resolve();
async function checkedFetch(path) {
  const response = await fetch(path);
  if (!response.ok) throw new Error(`${path}: HTTP ${response.status}. Run scripts/setup.ps1 and rebuild.`);
  return response;
}
async function dispatch(message) {
  switch (message.action) {
    case 'init': {
      const start = performance.now();
      const [module, models, tools] = await Promise.all([
        // The upstream wrapper resolves relative to the worker URL after importScripts.
        // Supply bytes explicitly so it does not request /needle.wasm instead of /vendor/needle.wasm.
        checkedFetch('vendor/needle.wasm').then(response => response.arrayBuffer()).then(wasmBinary => createNeedle({ wasmBinary })),
        Promise.all(['models/needle3.cact', 'models/whistle.cact'].map(async path => new Uint8Array(await (await checkedFetch(path)).arrayBuffer()))),
        (await checkedFetch('assets/assets/tools.json')).json(),
      ]);
      const downloaded = performance.now();
      engine = new Spike.SpikeEngine(module, tools);
      models.forEach(bytes => engine.load(bytes));
      const init = engine.init();
      return { ...init, fetch_and_wasm_ms: downloaded - start, load_and_prefix_ms: performance.now() - downloaded, total_init_ms: performance.now() - start };
    }
    case 'text':
      return { source: 'text', transcript: message.text, stt: null, routing: engine.route(message.text) };
    case 'audio':
      return engine.audio(new Float32Array(message.samples));
    case 'fixture':
      return engine.audio(Spike.readWav(new Uint8Array(await (await checkedFetch(`assets/assets/audio/${message.id}.wav`)).arrayBuffer())));
    case 'silence':
      return engine.audio(new Float32Array(16000));
    default: throw new Error(`Unknown worker action ${message.action}`);
  }
}
self.onmessage = ({ data }) => {
  // Needle's global model and output buffer are not thread-safe.
  sequence = sequence.then(async () => {
    try {
      if (!engine && data.action !== 'init') throw new Error('Initialize the engine first');
      self.postMessage({ requestId: data.requestId, result: await dispatch(data) });
    } catch (error) { self.postMessage({ requestId: data.requestId, error: String(error?.message || error) }); }
  });
};
