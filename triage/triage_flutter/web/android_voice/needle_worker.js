'use strict';
importScripts('vendor/needle.js', 'engine.js');
let engine;
let sequence = Promise.resolve();

async function checkedFetch(path) {
  const response = await fetch(path);
  if (!response.ok) throw new Error(`${path}: HTTP ${response.status}`);
  return response;
}

async function dispatch(message) {
  switch (message.action) {
    case 'init': {
      const [module, models, tools] = await Promise.all([
        checkedFetch('vendor/needle.wasm')
          .then(response => response.arrayBuffer())
          .then(wasmBinary => createNeedle({ wasmBinary })),
        Promise.all(['models/needle3.cact', 'models/whistle.cact'].map(async path =>
          new Uint8Array(await (await checkedFetch(path)).arrayBuffer()))),
        (await checkedFetch('assets/tools.json')).json(),
      ]);
      engine = new Spike.SpikeEngine(module, tools);
      models.forEach(bytes => engine.load(bytes));
      return engine.init();
    }
    case 'audio':
      if (!engine) throw new Error('Initialize the engine first');
      return engine.audio(new Float32Array(message.samples));
    case 'text':
      if (!engine) throw new Error('Initialize the engine first');
      return { source: 'text', transcript: message.text, stt: null, routing: engine.route(message.text) };
    default:
      throw new Error(`Unknown action: ${message.action}`);
  }
}

self.onmessage = ({ data }) => {
  sequence = sequence.then(async () => {
    try {
      self.postMessage({ requestId: data.requestId, result: await dispatch(data) });
    } catch (error) {
      self.postMessage({ requestId: data.requestId, error: String(error?.message || error) });
    }
  });
};
