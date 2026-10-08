'use strict';
let worker;
let serial = 0;
const pending = new Map();

function sendToWorker(action, payload = {}) {
  const requestId = ++serial;
  return new Promise((resolve, reject) => {
    pending.set(requestId, { resolve, reject });
    worker.postMessage({ requestId, action, ...payload });
  });
}

function receiveWorkerMessage({ data }) {
  const waiting = pending.get(data.requestId);
  if (!waiting) return;
  pending.delete(data.requestId);
  if (data.error) waiting.reject(new Error(data.error));
  else waiting.resolve(data.result);
}

async function decodePcm16Base64(encoded) {
  const binary = atob(encoded);
  if (!binary.length || binary.length % 2 !== 0 || binary.length > 960000) {
    throw new Error('Expected up to 30 seconds of mono PCM16 audio.');
  }
  const samples = new Float32Array(binary.length / 2);
  for (let offset = 0; offset < binary.length; offset += 2) {
    let sample = binary.charCodeAt(offset) | (binary.charCodeAt(offset + 1) << 8);
    if (sample & 0x8000) sample -= 0x10000;
    samples[offset / 2] = sample / 32768;
  }
  return samples;
}

window.triageNeedleReceive = async function (encoded) {
  let message;
  try {
    message = JSON.parse(encoded);
    if (message.action === 'init') {
      if (!worker) {
        worker = new Worker('needle_worker.js');
        worker.onmessage = receiveWorkerMessage;
        worker.onerror = event => {
          for (const waiter of pending.values()) waiter.reject(new Error(event.message || 'Needle worker failed'));
          pending.clear();
          worker?.terminate();
          worker = null;
        };
      }
      const result = await sendToWorker('init');
      window.TriageVoice.postMessage(JSON.stringify({ requestId: message.requestId, result }));
      return;
    }
    if (!worker) throw new Error('Needle engine is not initialized.');
    const payload = message.action === 'audio'
      ? { samples: (await decodePcm16Base64(message.pcm16Base64)).buffer }
      : { text: message.text };
    const result = await sendToWorker(message.action, payload);
    window.TriageVoice.postMessage(JSON.stringify({ requestId: message.requestId, result }));
  } catch (error) {
    window.TriageVoice.postMessage(JSON.stringify({
      requestId: message?.requestId,
      error: String(error?.message || error),
    }));
  }
};
