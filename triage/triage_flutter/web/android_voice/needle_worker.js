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
      const [module, whistle] = await Promise.all([
        checkedFetch('vendor/needle.wasm')
          .then(response => response.arrayBuffer())
          .then(wasmBinary => createNeedle({ wasmBinary })),
        checkedFetch('models/whistle.cact').then(async response => new Uint8Array(await response.arrayBuffer())),
      ]);
      engine = new TriageWhistle.WhistleEngine(module);
      engine.load(whistle);
      return { ready: true, stt_only: true, wasm_memory_bytes: module.HEAPU8.buffer.byteLength };
    }
    case 'audio':
      if (!engine) throw new Error('Initialize the engine first');
      const stt = engine.transcribe(new Float32Array(message.samples));
      return { source: 'audio', transcript: stt.parsed.text, stt };
    case 'text':
      if (!engine) throw new Error('Initialize the engine first');
      return { source: 'text', transcript: message.text, stt: null };
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
