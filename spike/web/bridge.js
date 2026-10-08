/* Browser audio capture + Promise<string> API for Dart JS interop. */
'use strict';
let worker, serial = 0, pending = new Map();
let capture = null;
let ready = false;
function request(action, payload = {}) {
  const id = ++serial;
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    worker.postMessage({ ...payload, action, requestId: id });
  });
}
function stopWorker(error) {
  ready = false;
  for (const waiter of pending.values()) waiter.reject(error);
  pending.clear();
  worker?.terminate();
  worker = null;
}
async function init() {
  if (ready) return { ready: true };
  worker = new Worker('needle_worker.js');
  worker.onmessage = ({ data }) => {
    const waiter = pending.get(data.requestId);
    if (!waiter) return;
    pending.delete(data.requestId);
    data.error ? waiter.reject(new Error(data.error)) : waiter.resolve(data.result);
  };
  worker.onerror = event => stopWorker(new Error(event.message || 'Needle worker failed'));
  try {
    const result = await request('init');
    ready = true;
    return result;
  } catch (error) { stopWorker(error); throw error; }
}
async function startCapture() {
  if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) throw new Error('Microphone requires HTTPS or localhost and getUserMedia support');
  if (capture) throw new Error('Already recording');
  const stream = await navigator.mediaDevices.getUserMedia({ audio: { channelCount: 1, echoCancellation: false, noiseSuppression: false, autoGainControl: false } });
  let context;
  try {
    context = new AudioContext();
    await context.resume();
    const source = context.createMediaStreamSource(stream);
    // Bare spike: ScriptProcessor works across the test browsers; replace with AudioWorklet for production.
    const processor = context.createScriptProcessor(4096, 1, 1);
    const silent = context.createGain();
    silent.gain.value = 0;
    const analyser = context.createAnalyser();
    analyser.fftSize = 256;
    const state = { context, source, processor, silent, analyser, stream, chunks: [], frames: 0, limit: 30 * context.sampleRate, ended: false };
    processor.onaudioprocess = event => {
      if (state.ended) return;
      const chunk = event.inputBuffer.getChannelData(0);
      const remaining = state.limit - state.frames;
      if (remaining > 0) {
        const copy = chunk.slice(0, remaining);
        state.chunks.push(copy);
        state.frames += copy.length;
      }
      if (state.frames >= state.limit) {
        state.ended = true;
        stream.getTracks().forEach(track => track.stop());
      }
    };
    source.connect(processor);
    source.connect(analyser);
    processor.connect(silent);
    silent.connect(context.destination);
    capture = state;
    return { recording: true, sample_rate: context.sampleRate, limit_seconds: 30 };
  } catch (error) {
    stream.getTracks().forEach(track => track.stop());
    if (context) await context.close();
    throw error;
  }
}
async function stopCapture() {
  const state = capture;
  if (!state) throw new Error('Not recording');
  capture = null;
  state.ended = true;
  state.processor.disconnect(); state.source.disconnect(); state.silent.disconnect(); state.analyser.disconnect();
  state.stream.getTracks().forEach(track => track.stop());
  await state.context.close();
  if (!state.frames) throw new Error('No audio captured. Try a longer recording.');
  const audio = new Float32Array(state.frames);
  let position = 0;
  for (const chunk of state.chunks) { audio.set(chunk, position); position += chunk.length; }
  const offline = new OfflineAudioContext(1, Math.min(480000, Math.round(state.frames * 16000 / state.context.sampleRate)), 16000);
  const buffer = offline.createBuffer(1, audio.length, state.context.sampleRate);
  buffer.copyToChannel(audio, 0);
  const source = offline.createBufferSource(); source.buffer = buffer; source.connect(offline.destination); source.start();
  const resampled = (await offline.startRendering()).getChannelData(0);
  const result = await request('audio', { samples: resampled.buffer });
  return { ...result, capture: { original_rate: state.context.sampleRate, truncated_at_30s: state.frames >= state.limit } };
}
window.triageSpike = async function (json) {
  const message = JSON.parse(json);
  let result;
  if (message.action === 'cancel') {
    const state = capture;
    capture = null;
    if (state) {
      state.ended = true;
      state.stream.getTracks().forEach(track => track.stop());
      state.source.disconnect(); state.processor.disconnect(); state.silent.disconnect(); state.analyser.disconnect();
      await state.context.close();
    }
    result = { cancelled: true };
  }
  else if (message.action === 'levels') {
    const levels = new Array(12).fill(0);
    if (capture && !capture.ended) {
      const bins = new Uint8Array(capture.analyser.frequencyBinCount);
      capture.analyser.getByteFrequencyData(bins);
      for (let i = 0; i < levels.length; i++) {
        const start = Math.floor(i * bins.length / levels.length);
        const end = Math.floor((i + 1) * bins.length / levels.length);
        for (let j = start; j < end; j++) levels[i] = Math.max(levels[i], bins[j] / 255);
      }
    }
    result = { levels };
  }
  else if (message.action === 'init') result = await init();
  else {
    if (!ready) throw new Error('Engine is not ready');
    if (message.action === 'start') result = await startCapture();
    else if (message.action === 'stop') result = await stopCapture();
    else result = await request(message.action, message);
  }
  return JSON.stringify(result);
};
window.addEventListener('pagehide', () => {
  capture?.stream.getTracks().forEach(track => track.stop());
  capture?.context.close();
  stopWorker(new Error('Page closed'));
});
