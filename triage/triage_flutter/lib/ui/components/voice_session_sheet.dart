import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../assistant/offline_assistant_controller.dart';
import '../../byok/byok_key_store.dart';
import '../../byok/llm_provider_adapter.dart';
import '../../parser/deterministic_action_parser.dart';
import '../../voice/gemini_live_session.dart';
import '../../voice/offline_voice_client.dart';
import 'ascii_cat_widget.dart';

enum VoiceMode { command, talk }

class VoiceSessionSheet extends StatefulWidget {
  const VoiceSessionSheet({
    super.key,
    required this.assistant,
    required this.voice,
    required this.keyStore,
    required this.onCommandResult,
    this.initialTranscript,
  });
  final OfflineAssistantController assistant;
  final OfflineVoiceClient voice;
  final ByokKeyStore keyStore;
  final void Function(AssistantLoopResult) onCommandResult;
  final String? initialTranscript;

  @override
  State<VoiceSessionSheet> createState() => _VoiceSessionSheetState();
}

class _VoiceSessionSheetState extends State<VoiceSessionSheet> {
  VoiceMode _mode = VoiceMode.command;
  GeminiLiveSession? _live;
  String _state = 'Ready';
  String _input = '';
  String _output = '';
  String _result = '';
  bool _busy = false;
  bool _recording = false;
  int _turnId = 0;
  bool _usedInitialTranscript = false;
  CatState _cat = CatState.idle;

  @override
  void initState() {
    super.initState();
    if (widget.initialTranscript != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startCommand());
    }
  }

  Future<void> _startCommand() async {
    if (_busy) return;
    final turn = ++_turnId;
    final override = _usedInitialTranscript ? null : widget.initialTranscript;
    _usedInitialTranscript = true;
    setState(() {
      _busy = true;
      _state = override == null ? 'Listening on device' : 'Working on device';
      _input = override ?? '';
      _result = '';
      _cat = CatState.listening;
    });
    try {
      final response = await widget.assistant.executeVoiceLoop(
        overrideTranscript: override,
        isCancelled: () => turn != _turnId,
      );
      if (!mounted || turn != _turnId) return;
      widget.onCommandResult(response);
      setState(() {
        _busy = false;
        _input = response.rawTranscript;
        _result = response.errorMessage ?? response.spokenFeedback;
        _state = response.isSuccess
            ? 'Command finished'
            : response.status == 'recognition_failed'
            ? 'Could not hear a command'
            : 'Command failed';
        _cat = response.isSuccess
            ? CatState.success
            : response.actionResult?.status.toString().contains(
                    'permissionRequired',
                  ) ==
                  true
            ? CatState.permissionRequired
            : CatState.error;
      });
    } catch (_) {
      if (mounted && turn == _turnId)
        setState(() {
          _busy = false;
          _state = 'Command failed';
          _result = 'Try again or check on-device speech settings.';
          _cat = CatState.error;
        });
    }
  }

  Future<void> _startTalk() async {
    if (_busy || _recording) return;
    setState(() {
      _busy = true;
      _state = 'Checking Talk';
      _result = '';
    });
    try {
      final key = await widget.keyStore.getApiKey(LlmProviderType.gemini);
      if (key == null || key.isEmpty)
        throw StateError('Add a Gemini key in Settings to use Talk.');
      final network = await Connectivity().checkConnectivity();
      if (!network.any((kind) => kind != ConnectivityResult.none))
        throw StateError('Talk needs a connection. Command works offline.');
      _live ??= GeminiLiveSession(
        apiKey: key,
        onEvent: _onLiveEvent,
        onAction: _confirmAction,
      );
      await _live!.startTurn();
      if (mounted)
        setState(() {
          _busy = false;
          _recording = true;
          _state = 'Listening to Talk';
          _cat = CatState.listening;
          _input = '';
          _output = '';
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _busy = false;
          _recording = false;
          _state = 'Talk unavailable';
          _result = error is StateError
              ? error.message
              : 'Could not connect to Gemini Live. Check model access, key, and connection, then retry.';
          _cat = CatState.error;
        });
    }
  }

  Future<void> _finishTalk() async {
    if (!_recording) return;
    setState(() {
      _recording = false;
      _busy = true;
      _state = 'Waiting for reply';
      _cat = CatState.thinking;
    });
    try {
      await _live!.finishTurn();
      if (mounted)
        setState(() {
          _busy = false;
          _state = 'Reply complete';
          _result = _output.isEmpty ? 'Gemini replied with audio.' : _output;
          _cat = CatState.success;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _busy = false;
          _state = 'Talk failed';
          if (_result.isEmpty) {
            _result =
                'Gemini did not complete this reply. Retry or use Command.';
          }
          _cat = CatState.error;
        });
    }
  }

  void _onLiveEvent(LiveEvent event) {
    if (!mounted) return;
    setState(() {
      switch (event.kind) {
        case 'interimInputTranscription':
        case 'inputTranscription':
          _input = event.text;
          break;
        case 'outputTranscription':
          _output += event.text;
          break;
        case 'error':
          _state = 'Talk failed';
          _result = event.text;
          _cat = CatState.error;
          _busy = false;
          _recording = false;
          break;
        case 'reconnecting':
          _state = event.text;
          break;
        case 'speaking':
          _state = event.text;
          _cat = CatState.thinking;
          break;
      }
    });
  }

  Future<String> _confirmAction(String command) async {
    final intent = DeterministicActionParser.parse(command);
    if (!intent.isMatched || intent.type == ActionType.unknown)
      return 'Rejected: unsupported phone action.';
    if (!mounted) return 'Rejected: session closed.';
    final result = await widget.assistant.executeVoiceLoop(
      overrideTranscript: command,
      speakTts: false,
    );
    widget.onCommandResult(result);
    if (mounted)
      setState(() {
        _result = result.errorMessage ?? result.spokenFeedback;
        _cat = result.isSuccess ? CatState.success : CatState.error;
      });
    return 'Phone action ${result.status}: ${result.errorMessage ?? result.spokenFeedback}';
  }

  Future<void> _cancel() async {
    ++_turnId;
    await widget.voice.cancelListening();
    await _live?.close();
    _live = null;
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    ++_turnId;
    widget.voice.cancelListening();
    _live?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Colors.white.withValues(alpha: .56);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          decoration: const BoxDecoration(
            color: Color(0xFF101010),
            border: Border(top: BorderSide(color: Color(0xFF44443F))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'Triage / voice',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Cancel voice session',
                    onPressed: _cancel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SegmentedButton<VoiceMode>(
                segments: const [
                  ButtonSegment(
                    value: VoiceMode.command,
                    label: Text('Command'),
                  ),
                  ButtonSegment(value: VoiceMode.talk, label: Text('Talk')),
                ],
                selected: {_mode},
                onSelectionChanged: (_busy || _recording)
                    ? null
                    : (value) async {
                        await _live?.close();
                        _live = null;
                        setState(() {
                          _mode = value.first;
                          _state = 'Ready';
                          _input = '';
                          _output = '';
                          _result = '';
                          _cat = CatState.idle;
                        });
                      },
              ),
              const SizedBox(height: 8),
              Text(
                _mode == VoiceMode.command
                    ? 'On-device actions · works offline'
                    : 'Gemini Live · online conversation',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: muted,
                ),
              ),
              Center(child: AsciiCatWidget(state: _cat, size: 150)),
              Text(
                _state,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFF44443F)),
                    bottom: BorderSide(color: Color(0xFF44443F)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOU',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: muted,
                      ),
                    ),
                    Text(
                      _input.isEmpty ? 'Your words appear here' : _input,
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (_output.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'TRIAGE',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: muted,
                        ),
                      ),
                      Text(_output, style: const TextStyle(fontSize: 16)),
                    ],
                  ],
                ),
              ),
              if (_result.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _result,
                    style: TextStyle(
                      color: _cat == CatState.error
                          ? const Color(0xFFFF8B82)
                          : Colors.white70,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _mode == VoiceMode.command
                    ? (_busy ? null : _startCommand)
                    : (_recording
                          ? _finishTalk
                          : _busy
                          ? null
                          : _startTalk),
                icon: Icon(_recording ? Icons.stop : Icons.mic),
                label: Text(
                  _recording
                      ? 'Finish turn'
                      : _busy
                      ? 'Working…'
                      : _state == 'Ready'
                      ? 'Start ${_mode.name}'
                      : 'Next turn',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _cancel, child: const Text('Cancel')),
            ],
          ),
        ),
      ),
    );
  }
}
