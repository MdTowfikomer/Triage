"""Windows native comparison using the official needle.transcribe API.

No web service, no cloud inference, no tool execution. SDK 3.1.0 and engine 3.2.0.
"""
import hashlib
import json
import os
from pathlib import Path
import platform
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / '.spike-cache' / 'python'))
os.environ['NEEDLE_TELEMETRY'] = '0'
os.environ['DO_NOT_TRACK'] = '1'
os.environ['NEEDLE3_LIB_PATH'] = str(ROOT.parent / '.spike-cache/native/libneedle3.dll')
# The explicit weights agent uses a separate process; make the locally installed SDK visible there.
os.environ['PYTHONPATH'] = str(ROOT.parent / '.spike-cache/python')


def main():
    import needle

    wasm = json.loads((ROOT.parent / 'docs/spike/benchmark.json').read_text(encoding='utf-8'))
    tools = json.loads((ROOT / 'assets/tools.json').read_text())
    utterances = json.loads((ROOT / 'assets/utterances.json').read_text())
    start = time.perf_counter()
    with needle.Needle(tools=tools, weights=ROOT / 'web/models/needle3.cact',
                       system=wasm['settings']['system'], auto_date=False, stateless=True) as agent:
        init_ms = (time.perf_counter() - start) * 1000
        rows = []
        for index, text in enumerate(utterances, 1):
            start = time.perf_counter()
            response = agent.complete(text, max_new_tokens=512)
            routing_ms = (time.perf_counter() - start) * 1000
            start = time.perf_counter()
            stt = needle.transcribe(ROOT / f'assets/audio/{index:02}.wav',
                                   weights=ROOT / 'web/models/whistle.cact',
                                   language='en', word_timestamps=True)
            stt_ms = (time.perf_counter() - start) * 1000
            start = time.perf_counter()
            audio_response = agent.complete(stt['text'], max_new_tokens=512)
            audio_routing_ms = (time.perf_counter() - start) * 1000
            rows.append(dict(id=index, input=text, text=response, routing_ms=routing_ms,
                             stt=stt, stt_ms=stt_ms, audio=audio_response,
                             audio_routing_ms=audio_routing_ms))
            print(f'{index}: native route {routing_ms:.1f}ms, STT {stt_ms:.1f}ms, confidence {response.get("confidence")}', flush=True)
        result = dict(runtime=f'cactus-needle {needle.__version__}, Windows native C FFI',
                      platform=platform.platform(), init_ms=init_ms, rows=rows,
                      dll_sha256=hashlib.sha256((ROOT.parent / '.spike-cache/native/libneedle3.dll').read_bytes()).hexdigest(),
                      settings=wasm['settings'], model_manifest=wasm['model_manifest'])
    target = ROOT.parent / 'docs/spike/native_benchmark.json'
    target.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(f'Saved {target}')


if __name__ == '__main__':
    main()
