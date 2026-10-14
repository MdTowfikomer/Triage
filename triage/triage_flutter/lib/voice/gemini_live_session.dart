import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:record/record.dart';

/// A phone-local Gemini Live connection. Audio and the BYOK key never touch Serverpod.
class GeminiLiveSession {
  GeminiLiveSession({
    required this.apiKey,
    this.onEvent,
    this.onAction,
    AudioRecorder? recorder,
    Future<WebSocket> Function()? socketConnector,
  }) : _recorder = recorder ?? AudioRecorder(),
       _socketConnector = socketConnector;

  static const model = 'gemini-3.8-live';
  static const _audio = MethodChannel('triage.live_audio');
  final String apiKey;
  final void Function(LiveEvent)? onEvent;
  final Future<String> Function(String)? onAction;
  final AudioRecorder _recorder;
  final Future<WebSocket> Function()? _socketConnector;
  WebSocket? _socket;
  StreamSubscription<Uint8List>? _microphone;
  Completer<void>? _setup;
  Completer<void>? _turn;
  Timer? _timeout;
  bool _closed = false;
  bool _capturing = false;
  bool _awaitingReply = false;
  int _capturedBytes = 0;
  int _pendingActions = 0;
  bool _receivedAudio = false;
  bool _serverTurnEnded = false;
  String? _lastActionResult;
  Timer? _ackTimeout;
  bool _ackRetrySent = false;
  String? _resumeHandle;

  bool get connected => _socket?.readyState == WebSocket.open;

  Future<void> connect() async {
    if (_closed) throw StateError('Session closed');
    if (connected) return;
    _setup = Completer<void>();
    try {
      _socket =
          await (_socketConnector?.call() ??
                  WebSocket.connect(
                    'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent',
                    headers: {'x-goog-api-key': apiKey},
                  ))
              .timeout(const Duration(seconds: 12));
      _socket!.listen(
        _receive,
        onError: _fail,
        onDone: () => _fail(StateError('Gemini disconnected')),
      );
      _send({
        'setup': {
          'model': 'models/$model',
          'generationConfig': {
            'responseModalities': ['AUDIO'],
          },
          'inputAudioTranscription': {},
          'outputAudioTranscription': {},
          'realtimeInputConfig': {
            'automaticActivityDetection': {'disabled': true},
          },
          'sessionResumption': {
            if (_resumeHandle != null) 'handle': _resumeHandle,
          },
          'contextWindowCompression': {'slidingWindow': {}},
          'systemInstruction': {
            'parts': [
              {
                'text':
                    'You are Triage, a calm, concise spoken phone assistant. '
                    'For any requested device action (volume, brightness, do not disturb, flashlight/torch, battery, apps, contacts, timers, or routines), call propose_phone_action with the normalized command immediately. Do not narrate, announce, or ask permission before the tool runs. '
                    'When the tool returns, speak exactly one brief sentence acknowledging the actual result, then stop and wait silently for the user. Never repeat the acknowledgement, add an offer of help, ask "anything else?", or start another turn. '
                    'If the action succeeded, do not ask a follow-up. Ask one short, specific question only when missing information or an action failure means the user must respond to continue; do not ask the user to repeat a task that already completed. '
                    'If contacts are ambiguous, speak the numbered options from the tool result. Accept a full name or ordinal on the next turn, then call the same action with that choice (for example call second). Do not repeat the original ambiguous name when the user chooses an option. '
                    'For note capture (take a note, remember, save an idea), first ask exactly: Is this an idea, note, or reminder? Keep the original content in context. Wait for the next user turn. Only after they choose a category, call the tool with save idea, save note, or save reminder followed by the original content. Never save a duplicate note. '
                    'Never greet or speak without a completed user recording. Ignore silence and background noise. '
                    'For a direct question or conversational message, answer once and concisely. Do not continue speaking after answering. Never be wordy.',
              },
            ],
          },
          'tools': [
            {
              'functionDeclarations': [
                {
                  'name': 'propose_phone_action',
                  'description':
                      'Execute the requested phone action locally. After the result, give one short spoken acknowledgement and then wait silently for the user.',
                  'parameters': {
                    'type': 'OBJECT',
                    'properties': {
                      'command': {
                        'type': 'STRING',
                        'description':
                            'The concrete phone command to execute, e.g. "set volume to 50%", "open WhatsApp", "turn on flashlight", "set brightness to 5%", "call Ammi", or "set a timer for 5 minutes".',
                      },
                    },
                    'required': ['command'],
                  },
                },
              ],
            },
          ],
        },
      });
      await _setup!.future.timeout(const Duration(seconds: 12));
      onEvent?.call(const LiveEvent('ready', 'Connected to Gemini Live'));
    } catch (error) {
      _fail(error);
      rethrow;
    }
  }

  Future<void> startTurn() async {
    await connect();
    if (_capturing || _awaitingReply) return;
    await _audio.invokeMethod<void>('stop');
    if (!await _recorder.hasPermission())
      throw StateError('Microphone permission required');
    _turn = Completer<void>();
    // Attach an error handler immediately, including before finishTurn is called.
    unawaited(_turn!.future.catchError((Object _) {}));
    _capturedBytes = 0;
    _receivedAudio = false;
    _serverTurnEnded = false;
    _lastActionResult = null;
    _ackRetrySent = false;
    _ackTimeout?.cancel();
    _capturing = true;
    onEvent?.call(const LiveEvent('listening', 'Listening'));
    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _send({
        'realtimeInput': {'activityStart': {}},
      });
      _microphone = stream.listen((bytes) {
        if (_capturing && connected) {
          _capturedBytes += bytes.length;
          _send({
            'realtimeInput': {
              'audio': {
                'data': base64Encode(bytes),
                'mimeType': 'audio/pcm;rate=16000',
              },
            },
          });
        }
      }, onError: _fail);
    } catch (_) {
      _capturing = false;
      rethrow;
    }
  }

  Future<void> finishTurn() async {
    if (!_capturing) return;
    _capturing = false;
    await _microphone?.cancel();
    await _recorder.stop();
    if (_capturedBytes == 0) {
      _send({
        'realtimeInput': {'activityEnd': {}},
      });
      throw StateError('No microphone audio received. Please try again.');
    }
    _awaitingReply = true;
    _send({
      'realtimeInput': {'activityEnd': {}},
    });
    onEvent?.call(const LiveEvent('thinking', 'Waiting for Gemini'));
    _timeout?.cancel();
    _timeout = Timer(
      const Duration(seconds: 30),
      () => _fail(TimeoutException('Gemini took too long to reply')),
    );
    await _turn?.future;
  }

  void _receive(dynamic payload) {
    try {
      final data =
          jsonDecode(
                payload is String ? payload : utf8.decode(payload as List<int>),
              )
              as Map<String, dynamic>;
      if (data.containsKey('setupComplete')) {
        if (!(_setup?.isCompleted ?? true)) _setup!.complete();
        return;
      }
      final handle =
          (data['sessionResumptionUpdate'] as Map?)?['newHandle'] as String?;
      if (handle != null && handle.isNotEmpty) _resumeHandle = handle;
      if (data.containsKey('goAway'))
        onEvent?.call(
          const LiveEvent('reconnecting', 'Gemini session is reconnecting'),
        );
      final calls = (data['toolCall'] as Map?)?['functionCalls'] as List?;
      if (calls != null && _awaitingReply) {
        for (final call in calls) {
          // Tool execution is asynchronous; contain failures here so a phone
          // action cannot become an unhandled Future error on the socket event.
          unawaited(_handleAction(Map<String, dynamic>.from(call as Map)));
        }
      }
      final content = data['serverContent'] as Map?;
      if (content == null) return;
      if (!_capturing && !_awaitingReply) return;
      for (final kind in [
        'interimInputTranscription',
        'inputTranscription',
        'outputTranscription',
      ]) {
        final value = (content[kind] as Map?)?['text'] as String?;
        if (value != null &&
            value.isNotEmpty &&
            (kind != 'outputTranscription' || _awaitingReply))
          onEvent?.call(LiveEvent(kind, value));
      }
      final parts =
          (content['modelTurn'] as Map?)?['parts'] as List? ?? const [];
      for (final part in parts) {
        final inline = (part as Map?)?['inlineData'] as Map?;
        if (inline?['data'] is String && _awaitingReply && !_capturing) {
          final bytes = base64Decode(inline!['data'] as String);
          _receivedAudio = true;
          _audio.invokeMethod<void>('playPcm', bytes);
          onEvent?.call(const LiveEvent('speaking', 'Gemini is speaking'));
        }
      }
      if (content['interrupted'] == true) _audio.invokeMethod<void>('stop');
      if (content['turnComplete'] == true && _awaitingReply) {
        _serverTurnEnded = true;
        if (_pendingActions == 0) unawaited(_completeTurn());
      }
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> _handleAction(Map<String, dynamic> call) async {
    _pendingActions++;
    final id = call['id'];
    final command = (call['args'] as Map?)?['command'] as String?;
    String result = _ackRetrySent
        ? (_lastActionResult ?? 'The previous action result is unavailable.')
        : 'Action rejected: invalid request';
    if (call['name'] == 'propose_phone_action' &&
        command != null &&
        onAction != null &&
        !_ackRetrySent) {
      try {
        result = await onAction!(command);
      } catch (error) {
        result = 'Phone action failed: ${_friendlyError(error)}';
      }
    }
    if (connected)
      _send({
        'toolResponse': {
          'functionResponses': [
            {
              'id': id,
              'name': call['name'],
              'response': {'result': result},
            },
          ],
        },
      });
    _lastActionResult = result;
    _pendingActions--;
    // A tool-only provider turn can end before the local action finishes.
    // Allow Gemini to acknowledge the tool response before falling back once.
    if (_awaitingReply && _pendingActions == 0) {
      _ackTimeout?.cancel();
      _ackTimeout = Timer(const Duration(seconds: 6), () {
        if (_awaitingReply && !_receivedAudio) unawaited(_completeTurn());
      });
      if (_serverTurnEnded) _serverTurnEnded = false;
    }
  }

  Future<void> _completeTurn() async {
    if (!_awaitingReply || _pendingActions != 0) return;
    _ackTimeout?.cancel();
    final result = _lastActionResult;
    if (!_receivedAudio && result != null) {
      if (!_ackRetrySent) {
        _ackRetrySent = true;
        final separator = result.indexOf(': ');
        final acknowledgement = separator >= 0
            ? result.substring(separator + 2)
            : result;
        _send({
          'clientContent': {
            'turns': [
              {
                'role': 'user',
                'parts': [
                  {
                    'text':
                        'The phone tool already returned this result: $result. '
                        'Do not execute or call any tool again. Speak exactly one concise acknowledgment in your voice now: $acknowledgement '
                        'If the result asks for missing information, speak that question instead. Then stop.',
                  },
                ],
              },
            ],
            'turnComplete': true,
          },
        });
        _ackTimeout = Timer(const Duration(seconds: 12), () {
          if (_awaitingReply && !_receivedAudio) {
            _fail(StateError('AUDIO_ACK_MISSING'));
          }
        });
        return;
      }
      _fail(StateError('AUDIO_ACK_MISSING'));
      return;
    }
    _awaitingReply = false;
    _timeout?.cancel();
    if (!(_turn?.isCompleted ?? true)) _turn!.complete();
    onEvent?.call(const LiveEvent('complete', 'Reply complete'));
  }

  void _send(Map<String, dynamic> value) {
    if (connected) _socket!.add(jsonEncode(value));
  }

  void _fail(Object error) {
    _awaitingReply = false;
    _capturing = false;
    unawaited(_microphone?.cancel() ?? Future<void>.value());
    unawaited(_recorder.stop().then<void>((_) {}, onError: (Object _) {}));
    _timeout?.cancel();
    _ackTimeout?.cancel();
    if (!(_setup?.isCompleted ?? true)) _setup!.completeError(error);
    if (!(_turn?.isCompleted ?? true)) _turn!.completeError(error);
    onEvent?.call(LiveEvent('error', _friendlyError(error)));
    _socket?.close();
    _socket = null;
  }

  static String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('AUDIO_ACK_MISSING')) {
      return 'Gemini’s spoken acknowledgment was unavailable. The phone action result is shown on screen.';
    }
    if (message.contains('404'))
      return 'Gemini Live model unavailable (404). Check model access and retry.';
    if (message.contains('503'))
      return 'Gemini Live is busy (503). Retry in a moment.';
    if (error is TimeoutException || message.contains('timed out'))
      return 'Gemini Live timed out. Retry or use Command.';
    return 'Gemini Live connection failed. Check the key and network, then retry.';
  }

  Future<void> close() async {
    _closed = true;
    _capturing = false;
    _awaitingReply = false;
    _timeout?.cancel();
    _ackTimeout?.cancel();
    await _microphone?.cancel();
    if (await _recorder.isRecording()) await _recorder.stop();
    await _recorder.dispose();
    await _audio.invokeMethod<void>('stop');
    await _socket?.close();
    _socket = null;
  }
}

class LiveEvent {
  const LiveEvent(this.kind, this.text);
  final String kind;
  final String text;
}
