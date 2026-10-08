import { Redact } from '@desert-ant-labs/redact';
import * as litert from '@litertjs/core';

let instance;
let loading;

async function model() {
  if (instance) return instance;
  loading ??= Redact.load({
    litert,
    litertWasmDir: 'vendor/litert/',
  });
  instance = await loading;
  return instance;
}

window.triageRedact = {
  async redactMany(texts) {
    const engine = await model();
    const results = [];
    for (const text of texts) {
      const result = await engine.redaction(text);
      results.push(result.redactedText);
    }
    return results;
  },
};
