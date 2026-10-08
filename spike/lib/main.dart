import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bridge.dart';

typedef SpikeInvoker = Future<String> Function(String request);

void main() => runApp(const SpikeApp());

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key, this.invoke = invokeSpike});
  final SpikeInvoker invoke;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Triage AI spike',
        theme: ThemeData(colorSchemeSeed: const Color(0xff287968)),
        home: SpikeScreen(invoke: invoke),
      );
}

class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key, required this.invoke});
  final SpikeInvoker invoke;

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  bool ready = false, busy = false, recording = false;
  String status = 'Initialize the local models to begin.';
  List<String> utterances = [];
  int selected = 0;
  Map<String, dynamic>? result;
  final transcript = TextEditingController();
  final runs = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadUtterances();
  }

  Future<void> _loadUtterances() async {
    final values = (jsonDecode(
      await rootBundle.loadString('assets/utterances.json'),
    ) as List)
        .cast<String>();
    if (mounted) {
      setState(() {
        utterances = values;
        transcript.text = values.first;
      });
    }
  }

  Future<void> _call(
    String action, [
    Map<String, dynamic> payload = const {},
  ]) async {
    if (busy) return;
    setState(() {
      busy = true;
      status = action == 'init'
          ? 'Loading Needle and Whistle…'
          : 'Processing $action…';
    });
    try {
      final value = jsonDecode(
        await widget.invoke(jsonEncode({'action': action, ...payload})),
      ) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        if (action == 'init') ready = true;
        if (action == 'start') recording = true;
        if (action == 'stop') recording = false;
        result = value;
        runs.add({'action': action, 'input': payload, 'result': value});
        status = recording
            ? 'Recording (maximum 30 seconds). Tap to stop.'
            : 'Ready. Results are experimental; no actions are executed.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (action == 'stop') recording = false;
        status = 'Error: $error';
        runs.add({'action': action, 'error': '$error'});
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    transcript.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canRun = ready && !busy && !recording;
    return Scaffold(
      appBar: AppBar(title: const Text('Triage AI spike')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Audio to Whistle to Needle',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 8),
              const Text(
                'Local inference. Five tools. Raw JSON and measured latency.',
              ),
              const SizedBox(height: 16),
              Semantics(liveRegion: true, child: Text(status)),
              if (busy) const LinearProgressIndicator(),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: busy || ready ? null : () => _call('init'),
                    child: const Text('Initialize models'),
                  ),
                  FilledButton.icon(
                    onPressed: ready && !busy
                        ? () => _call(recording ? 'stop' : 'start')
                        : null,
                    icon: Icon(recording ? Icons.stop : Icons.mic),
                    label: Text(recording ? 'Stop recording' : 'Record'),
                  ),
                  OutlinedButton(
                    onPressed: canRun ? () => _call('silence') : null,
                    child: const Text('Inject mock audio (silence)'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (utterances.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Benchmark utterance',
                  ),
                  items: [
                    for (var i = 0; i < utterances.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          '${i + 1}. ${utterances[i]}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: busy || recording
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              selected = value;
                              transcript.text = utterances[value];
                            });
                          }
                        },
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: canRun && utterances.isNotEmpty
                    ? () => _call('fixture', {
                          'id': (selected + 1).toString().padLeft(2, '0'),
                        })
                    : null,
                child: const Text('Inject prerecorded test WAV'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: transcript,
                minLines: 2,
                maxLines: 4,
                enabled: !busy && !recording,
                decoration: const InputDecoration(
                  labelText: 'Transcript (text-only routing test)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: canRun
                    ? () => _call('text', {'text': transcript.text})
                    : null,
                child: const Text('Route transcript'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text('Raw results', style: TextStyle(fontSize: 20)),
                  ),
                  TextButton(
                    onPressed: runs.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text: const JsonEncoder.withIndent('  ')
                                    .convert(runs),
                              ),
                            );
                            if (mounted) {
                              setState(
                                () => status = 'Run JSON copied to clipboard.',
                              );
                            }
                          },
                    child: const Text('Copy run JSON'),
                  ),
                ],
              ),
              SelectableText(
                result == null
                    ? 'No inference run yet.'
                    : const JsonEncoder.withIndent('  ').convert(result),
                key: const Key('raw-result'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
