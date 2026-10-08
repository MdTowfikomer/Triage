/* The mobile/web action funnel only uses Whistle STT from the shared WASM ABI. */
(function (root) {
  'use strict';
  const CAPACITY = 256 * 1024;
  class WhistleEngine {
    constructor(module) {
      this.module = module;
      this.modelPointers = [];
      this.output = module._malloc(CAPACITY);
      if (!this.output) throw new Error('Could not allocate STT response buffer');
    }
    check(code) {
      if (code < 0) throw new Error(this.module.ccall('needle_last_error', 'string', [], []) || 'Whistle failed');
    }
    load(bytes) {
      const module = this.module;
      const pointer = module._malloc(bytes.length);
      if (!pointer) throw new Error('Could not allocate Whistle model buffer');
      module.HEAPU8.set(bytes, pointer);
      try { this.check(module._needle_load(pointer, BigInt(bytes.length))); }
      catch (error) { module._free(pointer); throw error; }
      this.modelPointers.push(pointer);
    }
    transcribe(samples) {
      if (!(samples instanceof Float32Array) || !samples.length || samples.length > 480000 ||
          samples.some(sample => !Number.isFinite(sample) || Math.abs(sample) > 1)) {
        throw new Error('Expected 0–30 seconds of finite mono 16 kHz audio');
      }
      const module = this.module;
      const pointer = module._malloc(samples.byteLength);
      if (!pointer) throw new Error('Could not allocate audio buffer');
      try {
        new Float32Array(module.HEAPU8.buffer).set(samples, pointer / 4);
        const start = performance.now();
        this.check(module.ccall('needle_transcribe', 'number',
          ['number', 'number', 'string', 'number', 'number', 'number', 'number'],
          [pointer, samples.length, 'en', 0, 1, this.output, CAPACITY]));
        const raw = module.UTF8ToString(this.output);
        return { raw, parsed: JSON.parse(raw), latency_ms: performance.now() - start, duration_ms: samples.length / 16 };
      } finally { module._free(pointer); }
    }
  }
  root.TriageWhistle = { WhistleEngine };
})(typeof self !== 'undefined' ? self : globalThis);
