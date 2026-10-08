/* Shared by the browser worker and the headless Node benchmark. */
(function (root) {
  'use strict';
  // Needle's system turn accepts environment facts, not chatbot instructions.
  // Omit a date fact so relative dates remain available for Task 2's resolver.
  const SYSTEM = 'locale: en-US';
  const CAPACITY = 256 * 1024;

  function validate(response, tools) {
    const errors = [];
    const calls = response.function_calls;
    if (!Array.isArray(calls) || calls.length === 0) errors.push('No actionable function calls');
    for (const [index, call] of (Array.isArray(calls) ? calls : []).entries()) {
      const schema = tools.find(t => t.name === call.name)?.parameters;
      if (!schema) { errors.push(`Call ${index}: unknown tool ${call.name}`); continue; }
      const args = call.arguments;
      if (!args || typeof args !== 'object' || Array.isArray(args)) { errors.push(`Call ${index}: arguments must be an object`); continue; }
      for (const name of schema.required) {
        if (!(name in args)) errors.push(`Call ${index}: missing ${name}`);
      }
      for (const [name, value] of Object.entries(args)) {
        const property = schema.properties[name];
        if (!property) errors.push(`Call ${index}: unexpected ${name}`);
        else if (typeof value !== property.type || (property.enum && !property.enum.includes(value))) errors.push(`Call ${index}: invalid ${name}`);
      }
      for (const name of ['title', 'item', 'body', 'description', 'remind_at']) {
        if (name in schema.properties && (typeof args[name] !== 'string' || !args[name].trim())) errors.push(`Call ${index}: empty ${name}`);
      }
    }
    if (response.validation?.ungrounded?.length) errors.push('Engine flagged ungrounded arguments');
    if (response.validation?.negation) errors.push('Engine flagged negation');
    return { valid: errors.length === 0, errors };
  }

  class SpikeEngine {
    constructor(module, tools) {
      this.module = module;
      this.tools = tools;
      this.modelPointers = [];
      this.output = module._malloc(CAPACITY);
      if (!this.output) throw new Error('Could not allocate response buffer');
    }
    check(code) {
      if (code < 0) throw new Error(this.module.ccall('needle_last_error', 'string', [], []) || `Needle error ${code}`);
      return code;
    }
    load(bytes) {
      const m = this.module;
      const pointer = m._malloc(bytes.length);
      if (!pointer) throw new Error('Could not allocate model buffer');
      m.HEAPU8.set(bytes, pointer);
      try { this.check(m._needle_load(pointer, BigInt(bytes.length))); }
      catch (error) { m._free(pointer); throw error; }
      // Keep archives alive: the engine may map tensor data directly into them.
      this.modelPointers.push(pointer);
    }
    init() {
      this.prefixTokens = this.check(this.module.ccall('needle_init', 'number', ['string', 'string', 'number'], [SYSTEM, JSON.stringify(this.tools), 0]));
      return { prefix_tokens: this.prefixTokens, wasm_memory_bytes: this.module.HEAPU8.buffer.byteLength, system: SYSTEM };
    }
    response(code) {
      this.check(code);
      const raw = this.module.UTF8ToString(this.output);
      return { raw, parsed: JSON.parse(raw) };
    }
    route(transcript) {
      if (!transcript.trim()) return { skipped: true, reason: 'empty transcript', raw: null, parsed: null, latency_ms: 0 };
      const m = this.module;
      // Independent utterances must not inherit conversation state.
      m._needle_reset();
      const start = performance.now();
      const result = this.response(m.ccall('needle_complete', 'number', ['string', 'number', 'number', 'number', 'number', 'number'], [transcript, 0, 0, 512, this.output, CAPACITY]));
      return { ...result, latency_ms: performance.now() - start, schema: validate(result.parsed, this.tools) };
    }
    transcribe(samples) {
      if (!(samples instanceof Float32Array) || samples.length === 0 || samples.length > 30 * 16000) throw new Error('Audio must contain 0–30 seconds of 16 kHz mono float PCM');
      if (samples.some(x => !Number.isFinite(x) || Math.abs(x) > 1)) throw new Error('Audio samples must be finite and in [-1, 1]');
      const m = this.module;
      const pointer = m._malloc(samples.byteLength);
      if (!pointer) throw new Error('Could not allocate audio buffer');
      try {
        // malloc may grow memory, so use the current view.
        new Float32Array(m.HEAPU8.buffer).set(samples, pointer / 4);
        const start = performance.now();
        const result = this.response(m.ccall('needle_transcribe', 'number', ['number', 'number', 'string', 'number', 'number', 'number', 'number'], [pointer, samples.length, 'en', 0, 1, this.output, CAPACITY]));
        return { ...result, latency_ms: performance.now() - start, duration_ms: samples.length / 16 };
      } finally { m._free(pointer); }
    }
    audio(samples) {
      const start = performance.now();
      const stt = this.transcribe(samples);
      const routing = this.route(stt.parsed.text);
      return { source: 'audio', transcript: stt.parsed.text, stt, routing, total_latency_ms: performance.now() - start };
    }
  }

  function readWav(bytes) {
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const text = (offset, n) => String.fromCharCode(...bytes.subarray(offset, offset + n));
    if (bytes.length < 44 || text(0, 4) !== 'RIFF' || text(8, 4) !== 'WAVE') throw new Error('Expected a PCM WAV file');
    let format, pcm;
    for (let offset = 12; offset + 8 <= bytes.length;) {
      const size = view.getUint32(offset + 4, true);
      if (offset + 8 + size > bytes.length) throw new Error('Truncated WAV chunk');
      if (text(offset, 4) === 'fmt ') {
        if (size < 16) throw new Error('Truncated WAV format');
        format = { encoding: view.getUint16(offset + 8, true), channels: view.getUint16(offset + 10, true), rate: view.getUint32(offset + 12, true), bits: view.getUint16(offset + 22, true) };
      }
      if (text(offset, 4) === 'data') pcm = { offset: offset + 8, size };
      offset += 8 + size + (size % 2);
    }
    if (!format || !pcm || format.encoding !== 1 || format.channels !== 1 || format.rate !== 16000 || format.bits !== 16 || pcm.size % 2) throw new Error('Fixtures must be 16 kHz mono signed 16-bit PCM WAV');
    const samples = new Float32Array(pcm.size / 2);
    for (let i = 0; i < samples.length; i++) samples[i] = view.getInt16(pcm.offset + i * 2, true) / 32768;
    return samples;
  }
  const api = { SpikeEngine, readWav, validate, SYSTEM };
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.Spike = api;
})(globalThis);
