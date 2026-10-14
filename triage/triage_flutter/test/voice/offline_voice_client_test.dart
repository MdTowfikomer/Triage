import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triage_flutter/voice/offline_voice_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineVoiceClient client;
  final List<MethodCall> methodCalls = [];

  setUp(() {
    methodCalls.clear();
    client = OfflineVoiceClient();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('triage.offline_voice'),
      (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'checkCapabilities':
            return {
              'onDeviceRecognitionAvailable': true,
              'offlineTtsAvailable': true,
              'selectedVoiceName': 'en-us-x-sfg#female_1-local',
              'selectedLocale': 'en-US',
              'micPermissionGranted': true,
              'apiLevel': 34,
            };
          case 'startListening':
            return {
              'status': 'success',
              'transcript': 'set volume to fifty percent',
              'alternatives': ['set volume to fifty percent', 'set volume to 50%'],
              'sttLatencyMs': 142,
            };
          case 'stopListening':
            return true;
          case 'cancelListening':
            return true;
          case 'speakOffline':
            return {
              'status': 'success',
              'ttsLatencyMs': 86,
              'startLatencyMs': 24,
              'voice': 'en-us-x-sfg#female_1-local',
            };
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('triage.offline_voice'), null);
    client.dispose();
  });

  test('checkCapabilities parses on-device STT and offline TTS properties correctly', () async {
    final capabilities = await client.checkCapabilities();

    expect(capabilities.onDeviceRecognitionAvailable, isTrue);
    expect(capabilities.offlineTtsAvailable, isTrue);
    expect(capabilities.selectedVoiceName, equals('en-us-x-sfg#female_1-local'));
    expect(capabilities.selectedLocale, equals('en-US'));
    expect(capabilities.micPermissionGranted, isTrue);
    expect(capabilities.apiLevel, equals(34));
    expect(capabilities.isFullyOfflineCapable, isTrue);
  });

  test('startListening emits success with transcript and measured stt latency', () async {
    final result = await client.startListening();

    expect(result.isSuccess, isTrue);
    expect(result.status, equals('success'));
    expect(result.transcript, equals('set volume to fifty percent'));
    expect(result.sttLatencyMs, equals(142));
    expect(result.alternatives.length, equals(2));
  });

  test('speakOffline invokes platform method and returns measured tts latency', () async {
    final result = await client.speakOffline('Volume set to 50%');

    expect(result.isSuccess, isTrue);
    expect(result.status, equals('success'));
    expect(result.ttsLatencyMs, equals(86));
    expect(result.startLatencyMs, equals(24));
    expect(result.voice, equals('en-us-x-sfg#female_1-local'));
    expect(methodCalls.last.arguments, equals({'text': 'Volume set to 50%'}));
  });

  test('permission denied returns typed permission_required status', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('triage.offline_voice'),
      (MethodCall call) async {
        return {
          'status': 'permission_required',
          'code': 'MIC_PERMISSION_DENIED',
          'message': 'Microphone permission is required.',
        };
      },
    );

    final result = await client.startListening();

    expect(result.isSuccess, isFalse);
    expect(result.status, equals('permission_required'));
    expect(result.errorCode, equals('MIC_PERMISSION_DENIED'));
  });

  test('on-device unsupported returns typed unsupported status', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('triage.offline_voice'),
      (MethodCall call) async {
        return {
          'status': 'unsupported',
          'code': 'ON_DEVICE_RECOGNITION_UNAVAILABLE',
          'message': 'On-device speech recognition is not available on this device.',
        };
      },
    );

    final result = await client.startListening();

    expect(result.isSuccess, isFalse);
    expect(result.status, equals('unsupported'));
    expect(result.errorCode, equals('ON_DEVICE_RECOGNITION_UNAVAILABLE'));
  });

  test('openVoiceInputSettings and openTtsSettings invoke correct platform channels', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('triage.offline_voice'),
      (MethodCall call) async {
        methodCalls.add(call);
        return true;
      },
    );

    final resVoice = await client.openVoiceInputSettings();
    final resTts = await client.openTtsSettings();

    expect(resVoice, isTrue);
    expect(resTts, isTrue);
    expect(methodCalls.any((c) => c.method == 'openVoiceInputSettings'), isTrue);
    expect(methodCalls.any((c) => c.method == 'openTtsSettings'), isTrue);
  });
}
