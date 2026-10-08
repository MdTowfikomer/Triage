/* Real local WASM inference; never substitutes mock tool outputs. */
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const { SpikeEngine, readWav } = require('../web/engine.js');
const createNeedle = require('../web/vendor/needle.js');
const root = path.resolve(__dirname, '..');
const read = relative => fs.readFileSync(path.join(root, relative));
const json = relative => JSON.parse(read(relative).toString().replace(/^\uFEFF/, ''));
const hash = relative => crypto.createHash('sha256').update(read(relative)).digest('hex');

async function main() {
  const args = process.argv.slice(2);
  const output = args.includes('--out') ? args[args.indexOf('--out') + 1] : '../docs/spike/benchmark.json';
  const start = performance.now();
  const module = await createNeedle({ wasmBinary: read('web/vendor/needle.wasm') });
  const engine = new SpikeEngine(module, json('assets/tools.json'));
  const wasmInitMs = performance.now() - start;
  const loading = performance.now();
  engine.load(read('web/models/needle3.cact'));
  engine.load(read('web/models/whistle.cact'));
  const loadMs = performance.now() - loading;
  const prefixStart = performance.now();
  const init = engine.init();
  const prefixInitMs = performance.now() - prefixStart;
  const rows = [];
  const utterances = json('assets/utterances.json');
  for (let i = 0; i < utterances.length; i++) {
    const input = utterances[i];
    const text = engine.route(input);
    const filename = `assets/audio/${String(i + 1).padStart(2, '0')}.wav`;
    const audio = fs.existsSync(path.join(root, filename)) ? engine.audio(readWav(read(filename))) : { error: `Missing ${filename}; run scripts/make_audio.ps1` };
    rows.push({ id: i + 1, input, text, audio, audio_sha256: audio.error ? null : hash(filename) });
    console.log(`${i + 1}: text ${text.latency_ms.toFixed(1)}ms, STT ${audio.stt?.latency_ms.toFixed(1)}ms, ${JSON.stringify(text.parsed?.function_calls)}`);
  }
  const silence = engine.audio(new Float32Array(16000));
  const unrelated = engine.route('What is the capital of France?');
  const result = {
    recorded_at: new Date().toISOString(), runtime: `Node ${process.version} / official Needle WASM`,
    platform: `${os.platform()} ${os.arch()}`, cpu: os.cpus()[0]?.model,
    model_manifest: json('web/vendor/manifest.json'),
    tools_sha256: hash('assets/tools.json'), engine_wrapper_sha256: hash('web/engine.js'),
    audio_manifest: fs.existsSync(path.join(root, 'assets/audio/manifest.json')) ? json('assets/audio/manifest.json') : null,
    settings: { max_new_tokens: 512, language: 'en', word_timestamps: true, stateless: true, splitting: false, ...init },
    cold_start: { wasm_init_ms: wasmInitMs, model_load_ms: loadMs, prefix_init_ms: prefixInitMs },
    rows, controls: { silence, unrelated }, final_wasm_memory_bytes: module.HEAPU8.buffer.byteLength,
  };
  const target = path.resolve(root, output);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, JSON.stringify(result, null, 2) + '\n');
  console.log(`Saved ${target}`);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
