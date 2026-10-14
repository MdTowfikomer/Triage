import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:triage_flutter/voice/gemini_live_session.dart';

class _Microphone implements AudioRecorder {
  final chunks = StreamController<Uint8List>();
  bool recording = false;
  @override
  Future<bool> hasPermission({bool request = true}) async => true;
  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    recording = true;
    return chunks.stream;
  }

  @override
  Future<String?> stop() async {
    recording = false;
    return null;
  }

  @override
  Future<bool> isRecording() async => recording;
  @override
  Future<void> dispose() async => chunks.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Socket implements WebSocket {
  bool toolMode = false;
  bool toolAudio = false;
  final incoming = StreamController<dynamic>();
  final sent = <Map<String, dynamic>>[];
  @override
  int get readyState => WebSocket.open;
  @override
  void add(dynamic data) {
    final message = jsonDecode(data as String) as Map<String, dynamic>;
    sent.add(message);
    if (message.containsKey('setup')) emit({'setupComplete': {}});
    if ((message['realtimeInput'] as Map?)?.containsKey('activityEnd') ==
        true) {
      if (toolMode) {
        emit({
          'toolCall': {
            'functionCalls': [
              {
                'id': '1',
                'name': 'propose_phone_action',
                'args': {'command': 'set 5 min timer'},
              },
            ],
          },
        });
        emit({
          'serverContent': {'turnComplete': true},
        });
        return;
      }
      emit({
        'serverContent': {
          'modelTurn': {
            'parts': [
              {
                'inlineData': {
                  'data': base64Encode([1, 2]),
                },
              },
            ],
          },
          'turnComplete': true,
        },
      });
    }
    if (message.containsKey('toolResponse')) {
      emit({
        'serverContent': {
          if (toolAudio)
            'modelTurn': {
              'parts': [
                {
                  'inlineData': {
                    'data': base64Encode([1, 2]),
                  },
                },
              ],
            },
          'turnComplete': true,
        },
      });
    }
    if (message.containsKey('clientContent')) {
      emit({
        'serverContent': {
          'modelTurn': {
            'parts': [
              {
                'inlineData': {
                  'data': base64Encode([1, 2]),
                },
              },
            ],
          },
          'turnComplete': true,
        },
      });
    }
  }

  void emit(Map<String, dynamic> value) => incoming.add(jsonEncode(value));
  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => incoming.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  Future<void> close([int? code, String? reason]) async => incoming.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final hasAudio in [false, true]) {
    test(
      'tool acknowledgment survives early turnComplete, audio=$hasAudio',
      () async {
        final socket = _Socket()
          ..toolMode = true
          ..toolAudio = hasAudio;
        final microphone = _Microphone();
        var played = 0;
        var executed = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('triage.live_audio'),
              (call) async {
                if (call.method == 'playPcm') played++;
                return null;
              },
            );
        final live = GeminiLiveSession(
          apiKey: 'test',
          recorder: microphone,
          socketConnector: () async => socket,
          onAction: (_) async {
            executed++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return 'Action handed_off: Timer set for 5 minutes.';
          },
        );
        await live.startTurn();
        microphone.chunks.add(Uint8List.fromList([1, 2]));
        await Future<void>.delayed(Duration.zero);
        await live.finishTurn();
        expect(
          socket.sent.any((message) => message.containsKey('toolResponse')),
          isTrue,
        );
        expect(played, 1);
        expect(executed, 1);
        expect(
          socket.sent
              .where((message) => message.containsKey('clientContent'))
              .length,
          hasAudio ? 0 : 1,
        );
        await live.close();
      },
    );
  }
  test(
    'Live captures first, ends activity with mic stopped, and replies once',
    () async {
      final microphone = _Microphone();
      final socket = _Socket();
      var played = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('triage.live_audio'), (
            call,
          ) async {
            if (call.method == 'playPcm') {
              expect(microphone.recording, isFalse);
              played++;
            }
            return null;
          });
      final live = GeminiLiveSession(
        apiKey: 'test',
        recorder: microphone,
        socketConnector: () async => socket,
      );
      await live.startTurn();
      final setup = socket.sent.first['setup'] as Map;
      expect(
        (setup['realtimeInputConfig'] as Map)['automaticActivityDetection'],
        {'disabled': true},
      );
      socket.emit({
        'serverContent': {
          'modelTurn': {
            'parts': [
              {
                'inlineData': {
                  'data': base64Encode([1, 2]),
                },
              },
            ],
          },
        },
      });
      microphone.chunks.add(Uint8List.fromList([1, 2, 3, 4]));
      await Future<void>.delayed(Duration.zero);
      expect(played, 0);
      await live.finishTurn();
      expect(played, 1);
      expect(
        socket.sent.any(
          (m) =>
              (m['realtimeInput'] as Map?)?.containsKey('activityStart') ==
              true,
        ),
        isTrue,
      );
      expect(
        socket.sent.any(
          (m) =>
              (m['realtimeInput'] as Map?)?.containsKey('activityEnd') == true,
        ),
        isTrue,
      );
      expect(
        socket.sent.any(
          (m) =>
              (m['realtimeInput'] as Map?)?.containsKey('audioStreamEnd') ==
              true,
        ),
        isFalse,
      );
      socket.emit({
        'serverContent': {
          'modelTurn': {
            'parts': [
              {
                'inlineData': {
                  'data': base64Encode([1, 2]),
                },
              },
            ],
          },
        },
      });
      await Future<void>.delayed(Duration.zero);
      expect(played, 1);
      await live.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('triage.live_audio'),
            null,
          );
    },
  );
}
