import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../actions/action_result.dart';
import '../../assistant/offline_assistant_controller.dart';
import '../../byok/byok_key_store.dart';
import '../../byok/llm_provider_adapter.dart';
import '../../parser/deterministic_action_parser.dart';
import '../../voice/gemini_live_session.dart';
import '../../voice/offline_voice_client.dart';
import 'command_guide_modal.dart';
import 'illustrated_cat.dart';

enum AssistantVoiceRoute { checking, offline, live, failed }

/// A floating bottom-sheet card assistant overlay designed to feel like Siri / Gemini Assistant.
/// Can be summoned via shake gesture from anywhere (foreground, other tabs, or launched from background).
class AssistantOverlaySheet extends StatefulWidget {
  const AssistantOverlaySheet({
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

  static Future<void> show(
    BuildContext context, {
    required OfflineAssistantController assistant,
    required OfflineVoiceClient voice,
    required ByokKeyStore keyStore,
    required void Function(AssistantLoopResult) onCommandResult,
    String? initialTranscript,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => AssistantOverlaySheet(
        assistant: assistant,
        voice: voice,
        keyStore: keyStore,
        onCommandResult: onCommandResult,
        initialTranscript: initialTranscript,
      ),
    );
  }

  @override
  State<AssistantOverlaySheet> createState() => _AssistantOverlaySheetState();
}

class _AssistantOverlaySheetState extends State<AssistantOverlaySheet> {
  AssistantVoiceRoute _route = AssistantVoiceRoute.checking;
  GeminiLiveSession? _live;
  CatState _cat = CatState.listening;
  String _headline = 'Listening';
  String _detail = 'Listening to your command';
  String _input = '';
  String _reply = '';
  bool _recording = false;
  bool _busy = false;
  bool _turnComplete = false;
  int _generation = 0;
  String? _activeActionBadge;

  // Cat Meme & playful persona taglines
  static const List<String> _catMemes = [
    '🐱 Shaken, not stirred.',
    '🐾 At your paw-mand.',
    '😸 What task shall we pounce on?',
    '😼 Zero latency, pure meowgic.',
  ];
  late final String _selectedMeme;

  @override
  void initState() {
    super.initState();
    _selectedMeme = (List.of(_catMemes)..shuffle()).first;
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() async {
    if (widget.initialTranscript != null) {
      _route = AssistantVoiceRoute.offline;
      await _runCommand(widget.initialTranscript);
      return;
    }
    setState(() {
      _route = AssistantVoiceRoute.checking;
      _busy = true;
      _headline = 'Listening';
      _detail = 'Checking best voice route...';
    });
    final key = await widget.keyStore.getApiKey(LlmProviderType.gemini);
    final network = await Connectivity().checkConnectivity();
    if (!mounted) return;
    if (key == null ||
        key.isEmpty ||
        network.every((value) => value == ConnectivityResult.none)) {
      setState(() {
        _route = AssistantVoiceRoute.offline;
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
        _route = AssistantVoiceRoute.live;
        _busy = false;
        _detail = 'Gemini Live · ready';
      });
      await _startLiveTurn();
    } catch (_) {
      if (!mounted) return;
      await _live?.close();
      _live = null;
      setState(() {
        _route = AssistantVoiceRoute.offline;
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
      _route = AssistantVoiceRoute.offline;
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
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _headline = 'Couldn’t complete that';
          _reply = 'Please try again.';
          _cat = CatState.error;
        });
      }
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
      if (mounted) {
        setState(() {
          _busy = false;
          _recording = true;
          _headline = 'I’m listening';
          _cat = CatState.listening;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _route = AssistantVoiceRoute.failed;
          _headline = 'Couldn’t start';
          _detail = 'Check microphone access and your connection';
          _cat = CatState.error;
        });
      }
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
      if (mounted) {
        setState(() {
          _busy = false;
          _turnComplete = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _route = AssistantVoiceRoute.failed;
          _headline = 'Something went wrong';
          _detail =
              'Gemini didn’t respond. You can retry or use on-device commands.';
          _cat = CatState.error;
        });
      }
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
          _cat = CatState.speaking;
          _headline = 'Replying';
          break;
        case 'error':
          _route = AssistantVoiceRoute.failed;
          _headline = 'Connection lost';
          _detail = event.text;
          _cat = CatState.error;
          _recording = false;
          _busy = false;
          break;
      }
    });
  }

  Future<String> _confirmAction(String command) async {
    final intent = DeterministicActionParser.parse(command);
    if (!intent.isMatched || intent.type == ActionType.unknown) {
      return 'Rejected: unsupported phone action.';
    }
    if (!mounted) return 'Rejected: session closed.';

    String badgeText = 'Device action';
    switch (intent.type) {
      case ActionType.volume:
        badgeText = 'Volume: ${intent.targetPercent ?? ''}%';
        break;
      case ActionType.brightness:
        badgeText = 'Brightness: ${intent.brightnessPercent ?? ''}%';
        break;
      case ActionType.dnd:
        badgeText = 'DND: ${intent.dndEnabled == true ? 'On' : 'Off'}';
        break;
      case ActionType.timer:
        badgeText = 'Timer: ${intent.timerSeconds}s';
        break;
      case ActionType.alarm:
        badgeText =
            'Alarm: ${intent.alarmHour}:${intent.alarmMinute?.toString().padLeft(2, '0') ?? '00'}';
        break;
      case ActionType.dialContact:
        badgeText = 'Calling ${intent.contactName ?? 'contact'}';
        break;
      case ActionType.composeSms:
        badgeText = 'SMS to ${intent.contactName ?? 'contact'}';
        break;
      case ActionType.composeWhatsApp:
        badgeText = 'WhatsApp to ${intent.contactName ?? 'contact'}';
        break;
      case ActionType.openApp:
        badgeText = 'Open ${intent.appName ?? 'app'}';
        break;
      case ActionType.media:
        badgeText = 'Media: ${intent.mediaCommand ?? ''}';
        break;
      case ActionType.navigation:
        badgeText = 'Navigate: ${intent.destination ?? ''}';
        break;
      case ActionType.takeNote:
        badgeText = 'Note';
        break;
      default:
        badgeText = 'Device action';
        break;
    }

    setState(() {
      _activeActionBadge = badgeText;
      _cat = CatState.thinking;
    });

    final result = await widget.assistant.executeVoiceLoop(
      overrideTranscript: command,
      speakTts: false,
    );
    widget.onCommandResult(result);
    if (mounted) {
      setState(() {
        _reply = result.errorMessage ?? result.spokenFeedback;
        _cat = result.isSuccess ? CatState.success : CatState.error;
      });
    }
    return 'Action ${result.status}: ${result.errorMessage ?? result.spokenFeedback}';
  }

  Future<void> _exit() async {
    _generation++;
    await widget.voice.cancelListening();
    await _live?.close();
    _live = null;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _generation++;
    widget.voice.cancelListening();
    _live?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF242521);
    const muted = Color(0xFF777971);
    const paper = Color(0xFFF8F7F2);

    final modeBadge = _activeActionBadge != null
        ? _activeActionBadge!
        : _route == AssistantVoiceRoute.live
        ? 'Gemini Live'
        : 'On-device';

    return Container(
      decoration: const BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 28,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle Pill
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header bar: Meme tag / Title & Route badge & Close button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedMeme,
                            style: const TextStyle(
                              color: ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _detail,
                            style: const TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _activeActionBadge != null
                            ? const Color(0xFFFEF3C7)
                            : _route == AssistantVoiceRoute.live
                            ? const Color(0xFFEFF6FF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _activeActionBadge != null
                              ? const Color(0xFFFDE68A)
                              : _route == AssistantVoiceRoute.live
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
                                : _route == AssistantVoiceRoute.live
                                ? Icons.auto_awesome_rounded
                                : Icons.offline_bolt_outlined,
                            size: 11,
                            color: _activeActionBadge != null
                                ? const Color(0xFFB45309)
                                : _route == AssistantVoiceRoute.live
                                ? const Color(0xFF2563EB)
                                : muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            modeBadge,
                            style: TextStyle(
                              color: _activeActionBadge != null
                                  ? const Color(0xFFB45309)
                                  : _route == AssistantVoiceRoute.live
                                  ? const Color(0xFF1D4ED8)
                                  : muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      iconSize: 19,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Commands Guide',
                      onPressed: () => CommandGuideModal.show(context),
                      icon: const Icon(Icons.help_outline_rounded, color: muted),
                    ),
                    IconButton(
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Close Assistant',
                      onPressed: _exit,
                      icon: const Icon(Icons.close_rounded, color: muted),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 12),

              // Animated Cat Mascot
              Center(child: IllustratedCat(state: _cat, size: 160)),

              const SizedBox(height: 10),

              // Spoken feedback / transcript section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      _headline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    if (_input.isNotEmpty || _reply.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 120),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEFEFEA)),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_input.isNotEmpty)
                                Text(
                                  _input,
                                  style: const TextStyle(
                                    color: ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (_input.isNotEmpty && _reply.isNotEmpty)
                                const SizedBox(height: 6),
                              if (_reply.isNotEmpty)
                                Text(
                                  _reply,
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ink,
                      foregroundColor: paper,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _busy
                        ? null
                        : _recording
                        ? _finishLiveTurn
                        : _route == AssistantVoiceRoute.live
                        ? _startLiveTurn
                        : () => _runCommand(),
                    icon: Icon(
                      _recording ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 20,
                    ),
                    label: Text(
                      _recording
                          ? 'Finish speaking'
                          : _busy
                          ? 'Working…'
                          : _turnComplete
                          ? 'Tap to speak again'
                          : 'Speak now',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
