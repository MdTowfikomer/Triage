import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../actions/action_result.dart';
import '../assistant/offline_assistant_controller.dart';
import '../byok/byok_key_store.dart';
import '../byok/llm_provider_adapter.dart';
import '../parser/deterministic_action_parser.dart';
import '../voice/gemini_live_session.dart';
import '../voice/offline_voice_client.dart';
import 'components/command_guide_modal.dart';
import 'components/illustrated_cat.dart';

enum _VoiceRoute { checking, offline, live, failed }

class VoiceSessionPage extends StatefulWidget {
  const VoiceSessionPage({
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
  State<VoiceSessionPage> createState() => _VoiceSessionPageState();
}

class _VoiceSessionPageState extends State<VoiceSessionPage> {
  _VoiceRoute _route = _VoiceRoute.checking;
  GeminiLiveSession? _live;
  CatState _cat = CatState.idle;
  String _headline = 'Getting ready';
  String _detail = 'Checking the best way to help';
  String _input = '';
  String _reply = '';
  bool _recording = false;
  bool _busy = false;
  bool _turnComplete = false;
  int _generation = 0;
  String? _activeActionBadge;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() async {
    if (widget.initialTranscript != null) {
      _route = _VoiceRoute.offline;
      await _runCommand(widget.initialTranscript);
      return;
    }
    setState(() {
      _route = _VoiceRoute.checking;
      _busy = true;
      _headline = 'Getting ready';
      _detail = 'Checking Gemini Live';
    });
    final key = await widget.keyStore.getApiKey(LlmProviderType.gemini);
    final network = await Connectivity().checkConnectivity();
    if (!mounted) return;
    if (key == null ||
        key.isEmpty ||
        network.every((value) => value == ConnectivityResult.none)) {
      setState(() {
        _route = _VoiceRoute.offline;
        _busy = false;
        _detail = key == null || key.isEmpty
            ? 'On-device mode · add a Gemini key in Settings for conversation'
            : 'On-device mode · no connection';
      });
      await _runCommand();
      return;
    }
    try {
      _live ??= GeminiLiveSession(
        apiKey: key,
        onEvent: _onLiveEvent,
        onAction: _confirmAction,
      );
      await _live!.connect();
      if (!mounted) return;
      setState(() {
        _route = _VoiceRoute.live;
        _busy = false;
        _detail = 'Gemini Live · online';
      });
      await _startLiveTurn();
    } catch (_) {
      if (!mounted) return;
      await _live?.close();
      _live = null;
      setState(() {
        _route = _VoiceRoute.offline;
        _busy = false;
        _detail = 'Gemini unavailable · using on-device commands';
      });
      await _runCommand();
    }
  }

  Future<void> _runCommand([String? override]) async {
    if (_busy) return;
    final generation = ++_generation;
    setState(() {
      _route = _VoiceRoute.offline;
      _busy = true;
      _headline = override == null ? 'Listening' : 'Working on it';
      _cat = override == null ? CatState.listening : CatState.thinking;
      _input = override ?? '';
      _reply = '';
      _turnComplete = false;
    });
    try {
      final result = await widget.assistant.executeVoiceLoop(
        overrideTranscript: override,
        isCancelled: () => generation != _generation,
      );
      if (!mounted || generation != _generation) return;
      widget.onCommandResult(result);
      setState(() {
        _busy = false;
        _turnComplete = true;
        _input = result.rawTranscript;
        _reply = result.errorMessage ?? result.spokenFeedback;
        _headline = result.actionResult?.status == ActionStatus.handedOff
            ? 'Sent to your phone'
            : result.isSuccess
            ? 'Done'
            : result.actionResult?.status == ActionStatus.permissionRequired
            ? 'Permission needed'
            : 'Couldn’t complete that';
        _cat = result.isSuccess
            ? CatState.success
            : result.actionResult?.status == ActionStatus.permissionRequired
            ? CatState.permissionRequired
            : CatState.error;
      });
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() {
          _busy = false;
          _headline = 'Couldn’t complete that';
          _reply = 'Please try again.';
          _cat = CatState.error;
        });
    }
  }

  Future<void> _startLiveTurn() async {
    if (_busy || _recording) return;
    setState(() {
      _busy = true;
      _headline = 'Connecting';
      _input = '';
      _reply = '';
      _turnComplete = false;
    });
    try {
      await _live!.startTurn();
      if (mounted)
        setState(() {
          _busy = false;
          _recording = true;
          _headline = 'I’m listening';
          _cat = CatState.listening;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _busy = false;
          _route = _VoiceRoute.failed;
          _headline = 'Couldn’t start';
          _detail = 'Check microphone access and your connection';
          _cat = CatState.error;
        });
    }
  }

  Future<void> _finishLiveTurn() async {
    if (!_recording) return;
    setState(() {
      _recording = false;
      _busy = true;
      _headline = 'Thinking';
      _cat = CatState.thinking;
    });
    try {
      await _live!.finishTurn();
      if (mounted)
        setState(() {
          _busy = false;
          _turnComplete = true;
          _headline = 'Here you go';
          _cat = CatState.success;
          if (_reply.isEmpty) _reply = 'Spoken reply complete';
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _busy = false;
          _route = _VoiceRoute.failed;
          _headline = 'Gemini couldn’t reply';
          _cat = CatState.error;
          if (_reply.isEmpty)
            _reply = 'Retry online or use an on-device command.';
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
          _reply += event.text;
          break;
        case 'speaking':
          _headline = 'Speaking';
          _cat = CatState.speaking;
          break;
        case 'error':
          _route = _VoiceRoute.failed;
          _recording = false;
          _busy = false;
          _headline = 'Gemini couldn’t reply';
          _detail = event.text;
          _cat = CatState.error;
          break;
        case 'reconnecting':
          _detail = 'Reconnecting to Gemini';
          break;
      }
    });
  }

  Future<String> _confirmAction(String command) async {
    final intent = DeterministicActionParser.parse(command);
    if (!intent.isMatched || intent.type == ActionType.unknown)
      return 'Rejected: unsupported phone action.';
    if (!mounted) return 'Rejected: voice session closed.';

    setState(() {
      _activeActionBadge = '📱 On-device action';
    });

    final result = await widget.assistant.executeVoiceLoop(
      overrideTranscript: command,
      speakTts: false, // Gemini Live provides the voice confirmation
    );
    widget.onCommandResult(result);
    if (mounted)
      setState(() {
        _reply = result.errorMessage ?? result.spokenFeedback;
        _cat = result.isSuccess ? CatState.success : CatState.error;
      });
    return 'Phone action ${result.status}: ${result.errorMessage ?? result.spokenFeedback}';
  }

  Future<void> _exit() async {
    ++_generation;
    await widget.voice.cancelListening();
    await _live?.close();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    ++_generation;
    widget.voice.cancelListening();
    _live?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF242521), muted = Color(0xFF777971);
    final mode = _route == _VoiceRoute.live
        ? 'Gemini Live'
        : _route == _VoiceRoute.checking
        ? 'Finding a connection'
        : _route == _VoiceRoute.failed
        ? 'Connection interrupted'
        : 'On-device command';
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 12, 26, 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Close voice',
                            onPressed: _exit,
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Commands Guide',
                            onPressed: () => CommandGuideModal.show(context),
                            icon: const Icon(Icons.help_outline_rounded, color: muted),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _activeActionBadge != null
                                  ? const Color(0xFFFEF3C7)
                                  : _route == _VoiceRoute.live
                                  ? const Color(0xFFEFF6FF)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _activeActionBadge != null
                                    ? const Color(0xFFFDE68A)
                                    : _route == _VoiceRoute.live
                                    ? const Color(0xFFDBEAFE)
                                    : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _activeActionBadge != null
                                      ? Icons.phone_android_rounded
                                      : _route == _VoiceRoute.live
                                      ? Icons.auto_awesome_rounded
                                      : Icons.offline_bolt_outlined,
                                  size: 13,
                                  color: _activeActionBadge != null
                                      ? const Color(0xFFB45309)
                                      : _route == _VoiceRoute.live
                                      ? const Color(0xFF2563EB)
                                      : muted,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _activeActionBadge ?? mode,
                                  style: TextStyle(
                                    color: _activeActionBadge != null
                                        ? const Color(0xFFB45309)
                                        : _route == _VoiceRoute.live
                                        ? const Color(0xFF1D4ED8)
                                        : muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IllustratedCat(state: _cat, size: 240),
                      const SizedBox(height: 22),
                      Text(
                        _headline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _detail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: muted, fontSize: 14),
                      ),
                      const Spacer(),
                      if (_input.isNotEmpty || _reply.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_input.isNotEmpty)
                                Text(
                                  _input,
                                  style: const TextStyle(
                                    color: ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (_input.isNotEmpty && _reply.isNotEmpty)
                                const SizedBox(height: 12),
                              if (_reply.isNotEmpty)
                                Text(
                                  _reply,
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 22),
                      if (_route == _VoiceRoute.failed) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            onPressed: _busy ? null : _begin,
                            child: const Text('Retry online'),
                          ),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => _runCommand(),
                          child: const Text('Use on-device Command'),
                        ),
                      ] else
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : _recording
                                ? _finishLiveTurn
                                : _route == _VoiceRoute.live
                                ? _startLiveTurn
                                : _route == _VoiceRoute.offline
                                ? () => _runCommand()
                                : null,
                            icon: Icon(
                              _recording
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                            ),
                            label: Text(
                              _recording
                                  ? 'Finish speaking'
                                  : _busy
                                  ? 'Working…'
                                  : _turnComplete
                                  ? 'Speak again'
                                  : 'Start speaking',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
