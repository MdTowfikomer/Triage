import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:triage_flutter/actions/native_action_client.dart';
import 'package:triage_flutter/assistant/offline_assistant_controller.dart';
import 'package:triage_flutter/voice/offline_voice_client.dart';
import 'package:triage_flutter/outbox/local_outbox_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineVoiceClient voiceClient;
  late NativeActionClient actionClient;
  late LocalOutboxRepository outboxRepo;
  late OfflineAssistantController controller;

  final List<MethodCall> voiceCalls = [];
  final List<MethodCall> actionCalls = [];

  setUp(() async {
    voiceCalls.clear();
    actionCalls.clear();

    voiceClient = OfflineVoiceClient();
    actionClient = NativeActionClient();
    outboxRepo = LocalOutboxRepository();
    final inMemoryDb = sqlite3.openInMemory();
    await outboxRepo.initialize(customDb: inMemoryDb);

    controller = OfflineAssistantController(
      voiceClient: voiceClient,
      actionClient: actionClient,
      outboxRepository: outboxRepo,
    );

    // Mock OfflineVoiceBridge channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('triage.offline_voice'),
      (MethodCall call) async {
        voiceCalls.add(call);
        switch (call.method) {
          case 'startListening':
            return {
              'status': 'success',
              'transcript': 'set volume to 50 percent',
              'sttLatencyMs': 25,
            };
          case 'speakOffline':
            return {
              'status': 'success',
              'ttsLatencyMs': 80,
              'startLatencyMs': 15,
            };
          default:
            return null;
        }
      },
    );

    // Mock NativeActionBridge channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('triage.native_actions'),
      (MethodCall call) async {
        actionCalls.add(call);
        switch (call.method) {
          case 'setVolume':
            final dynamic raw = call.arguments['percent'];
            final val = (raw as num?)?.toInt() ?? 0;
            return {
              'status': 'success',
              'action': 'set_volume',
              'previousValue': 20,
              'targetValue': val,
              'executionLatencyMs': 9,
              'errorCode': null,
              'errorMessage': null,
            };
          case 'setBrightness':
            final dynamic raw = call.arguments['percent'];
            final val = (raw as num?)?.toInt() ?? 50;
            return {
              'status': 'success',
              'action': 'set_brightness',
              'previousValue': 30,
              'targetValue': val,
              'executionLatencyMs': 12,
              'errorCode': null,
              'errorMessage': null,
            };
          case 'setDoNotDisturb':
            final bool enabled = call.arguments['enabled'] == true;
            return {
              'status': 'success',
              'action': 'set_dnd',
              'previousValue': enabled ? 0 : 1,
              'targetValue': enabled ? 1 : 0,
              'executionLatencyMs': 15,
              'errorCode': null,
              'errorMessage': null,
            };
          case 'setTimer':
            return {
              'status': 'handed_off',
              'action': 'set_timer',
              'previousValue': null,
              'targetValue': call.arguments['seconds'],
              'executionLatencyMs': 18,
              'errorCode': null,
              'errorMessage': null,
            };
          case 'setAlarm':
            return {
              'status': 'handed_off',
              'action': 'set_alarm',
              'previousValue': null,
              'targetValue': null,
              'executionLatencyMs': 20,
              'errorCode': null,
              'errorMessage': null,
            };
          case 'openApp':
            return {
              'status': 'success',
              'action': 'open_app',
              'previousValue': null,
              'targetValue': call.arguments['app'],
              'executionLatencyMs': 25,
              'errorCode': null,
              'errorMessage': null,
            };
          case 'mediaControl':
            return {
              'status': 'handed_off',
              'action': 'media_control',
              'previousValue': null,
              'targetValue': call.arguments['command'],
              'executionLatencyMs': 7,
              'errorCode': null,
              'errorMessage': null,
            };
          default:
            return null;
        }
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('triage.offline_voice'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('triage.native_actions'),
      null,
    );
    await outboxRepo.dispose();
  });

  group('OfflineAssistantController End-to-End Loop Tests', () {
    test('executes complete offline cycle: STT -> parse -> outbox attempt -> native setVolume -> outbox success -> TTS', () async {
      final loopResult = await controller.executeVoiceLoop();

      expect(loopResult.isSuccess, isTrue);
      expect(loopResult.status, equals('success'));
      expect(loopResult.rawTranscript, equals('set volume to 50 percent'));
      expect(loopResult.intent.targetPercent, equals(50));
      expect(loopResult.actionResult?.targetValue, equals(50));
      expect(loopResult.spokenFeedback, equals('Volume set to 50 percent.'));
      expect(loopResult.sttLatencyMs, equals(25));
      expect(loopResult.execLatencyMs, equals(9));

      // Verify outbox entry in local SQLite
      expect(loopResult.eventId, isNotNull);
      final outboxEntry = await outboxRepo.getEvent(loopResult.eventId!);
      expect(outboxEntry, isNotNull);
      expect(outboxEntry!.status, equals('success'));
      expect(outboxEntry.requestedValue, equals(50));
      expect(outboxEntry.actualValue, equals(50));
      expect(outboxEntry.previousValue, equals(20));
      expect(outboxEntry.completedAt, isNotNull);

      // Verify channel dispatches
      expect(voiceCalls.any((c) => c.method == 'startListening'), isTrue);
      expect(actionCalls.any((c) => c.method == 'setVolume'), isTrue);
      expect(voiceCalls.any((c) => c.method == 'speakOffline'), isTrue);
    });

    test('executes screen brightness adjustment across complete loop', () async {
      final loopResult = await controller.executeVoiceLoop(overrideTranscript: 'set brightness to 70 percent');

      expect(loopResult.isSuccess, isTrue);
      expect(loopResult.status, equals('success'));
      expect(loopResult.intent.brightnessPercent, equals(70));
      expect(loopResult.spokenFeedback, equals('Screen brightness set to 70 percent.'));
      expect(actionCalls.any((c) => c.method == 'setBrightness' && c.arguments['percent'] == 70), isTrue);

      final outboxEntry = await outboxRepo.getEvent(loopResult.eventId!);
      expect(outboxEntry, isNotNull);
      expect(outboxEntry!.intent, equals('set_brightness'));
      expect(outboxEntry.status, equals('success'));
      expect(outboxEntry.actualValue, equals(70));
    });

    test('executes Do Not Disturb toggle across complete loop', () async {
      final loopResult = await controller.executeVoiceLoop(overrideTranscript: 'turn on do not disturb');

      expect(loopResult.isSuccess, isTrue);
      expect(loopResult.status, equals('success'));
      expect(loopResult.intent.dndEnabled, isTrue);
      expect(loopResult.spokenFeedback, equals('Do Not Disturb turned on.'));
      expect(actionCalls.any((c) => c.method == 'setDoNotDisturb' && c.arguments['enabled'] == true), isTrue);

      final outboxEntry = await outboxRepo.getEvent(loopResult.eventId!);
      expect(outboxEntry, isNotNull);
      expect(outboxEntry!.intent, equals('set_dnd'));
      expect(outboxEntry.status, equals('success'));
      expect(outboxEntry.actualValue, equals(1));
    });

    test('executes timer creation with truthful handed_off status', () async {
      final loopResult = await controller.executeVoiceLoop(overrideTranscript: 'set a timer for 5 minutes');

      expect(loopResult.isSuccess, isTrue);
      expect(loopResult.status, equals('handed_off'));
      expect(loopResult.intent.timerSeconds, equals(300));
      expect(loopResult.spokenFeedback, equals('Timer set for 5 minutes.'));
      expect(actionCalls.any((c) => c.method == 'setTimer' && c.arguments['seconds'] == 300), isTrue);

      final outboxEntry = await outboxRepo.getEvent(loopResult.eventId!);
      expect(outboxEntry, isNotNull);
      expect(outboxEntry!.intent, equals('set_timer'));
      expect(outboxEntry.status, equals('handed_off'));
    });

    test('executes alarm creation with truthful handed_off status', () async {
      final loopResult = await controller.executeVoiceLoop(overrideTranscript: 'set alarm for 7:30 am');

      expect(loopResult.isSuccess, isTrue);
      expect(loopResult.status, equals('handed_off'));
      expect(loopResult.intent.alarmHour, equals(7));
      expect(loopResult.intent.alarmMinute, equals(30));
      expect(loopResult.spokenFeedback, equals('Alarm set for 7:30 AM.'));
      expect(actionCalls.any((c) => c.method == 'setAlarm' && c.arguments['hour'] == 7 && c.arguments['minutes'] == 30), isTrue);

      final outboxEntry = await outboxRepo.getEvent(loopResult.eventId!);
      expect(outboxEntry, isNotNull);
      expect(outboxEntry!.intent, equals('set_alarm'));
      expect(outboxEntry.status, equals('handed_off'));
    });

    test('executes app launching with scoped queries', () async {
      final loopResult = await controller.executeVoiceLoop(overrideTranscript: 'open camera');

      expect(loopResult.isSuccess, isTrue);
      expect(loopResult.status, equals('success'));
      expect(loopResult.intent.appName, equals('camera'));
      expect(loopResult.spokenFeedback, equals('Opening camera.'));
      expect(actionCalls.any((c) => c.method == 'openApp' && c.arguments['app'] == 'camera'), isTrue);

      final outboxEntry = await outboxRepo.getEvent(loopResult.eventId!);
      expect(outboxEntry, isNotNull);
      expect(outboxEntry!.intent, equals('open_app'));
      expect(outboxEntry.status, equals('success'));
    });

    test('executes media track skipping with truthful handed_off status', () async {
      final loopResult = await controller.executeVoiceLoop(overrideTranscript: 'next track');

      expect(loopResult.isSuccess, isTrue);
      expect(loopResult.status, equals('handed_off'));
      expect(loopResult.intent.mediaCommand, equals('next'));
      expect(loopResult.spokenFeedback, equals('Skipping to next track.'));
      expect(actionCalls.any((c) => c.method == 'mediaControl' && c.arguments['command'] == 'next'), isTrue);

      final outboxEntry = await outboxRepo.getEvent(loopResult.eventId!);
      expect(outboxEntry, isNotNull);
      expect(outboxEntry!.intent, equals('media_control'));
      expect(outboxEntry.status, equals('handed_off'));
    });

    test('handles permission_required truthfully when settings access is denied', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('triage.native_actions'),
        (MethodCall call) async {
          if (call.method == 'setBrightness') {
            return {
              'status': 'permission_required',
              'action': 'set_brightness',
              'errorCode': 'WRITE_SETTINGS_DENIED',
              'errorMessage': 'WRITE_SETTINGS permission required',
            };
          }
          return null;
        },
      );

      final loopResult = await controller.executeVoiceLoop(overrideTranscript: 'set brightness to 50 percent');

      expect(loopResult.isSuccess, isFalse);
      expect(loopResult.status, equals('permission_required'));
      expect(loopResult.spokenFeedback, contains('Write Settings permission is required'));

      final outboxEntry = await outboxRepo.getEvent(loopResult.eventId!);
      expect(outboxEntry, isNotNull);
      expect(outboxEntry!.status, equals('permission_required'));
      expect(outboxEntry.errorCode, equals('WRITE_SETTINGS_DENIED'));
    });

    test('handles unrecognized intent with polite TTS and no native execution', () async {
      final loopResult = await controller.executeVoiceLoop(overrideTranscript: 'what time is it');

      expect(loopResult.isSuccess, isFalse);
      expect(loopResult.status, equals('intent_unmatched'));
      expect(loopResult.intent.isMatched, isFalse);
      expect(loopResult.spokenFeedback, contains('could not recognize'));

      // Action client must NOT be called for unrecognized intent
      expect(actionCalls.isEmpty, isTrue);

      // No outbox event written for unrecognized intent
      expect(loopResult.eventId, isNull);
    });

    test('strictly rejects negated commands before any outbox attempt or device action', () async {
      final loopResult = await controller.executeVoiceLoop(overrideTranscript: "Don't set volume to 50");

      expect(loopResult.isSuccess, isFalse);
      expect(loopResult.status, equals('intent_unmatched'));
      expect(loopResult.intent.isMatched, isFalse);
      expect(loopResult.spokenFeedback, contains('could not recognize'));

      // Neither native actions nor outbox attempts are staged
      expect(actionCalls.isEmpty, isTrue);
      expect(loopResult.eventId, isNull);
      final events = await outboxRepo.getRecentEvents();
      expect(events.isEmpty, isTrue);
    });

    test('preserves hardware success when TTS playback fails, reporting speech delivery failure separately', () async {
      // Mock TTS to fail
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('triage.offline_voice'),
        (MethodCall call) async {
          if (call.method == 'startListening') {
            return {
              'status': 'success',
              'transcript': 'set volume to 80',
              'sttLatencyMs': 20,
            };
          }
          if (call.method == 'speakOffline') {
            return {
              'status': 'error',
              'code': 'TTS_ENGINE_UNAVAILABLE',
              'message': 'Offline TTS synthesis engine not bound',
            };
          }
          return null;
        },
      );

      final loopResult = await controller.executeVoiceLoop();

      // Hardware execution must succeed
      expect(loopResult.isSuccess, isTrue);
      expect(loopResult.status, equals('success'));
      expect(loopResult.actionResult?.isSuccess, isTrue);
      expect(loopResult.actionResult?.targetValue, equals(80));

      // Speech delivery must be reported as failed separately
      expect(loopResult.isSpeechDelivered, isFalse);
      expect(loopResult.speechError, contains('Offline TTS synthesis engine not bound'));

      // Outbox status remains success
      final outboxEntry = await outboxRepo.getEvent(loopResult.eventId!);
      expect(outboxEntry!.status, equals('success'));
    });
  });
}
