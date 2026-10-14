import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triage_flutter/actions/action_result.dart';
import 'package:triage_flutter/actions/native_action_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NativeActionClient client;
  final List<MethodCall> methodCalls = [];
  int currentMockVolume = 25;

  setUp(() {
    methodCalls.clear();
    currentMockVolume = 25;
    client = NativeActionClient();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('triage.native_actions'),
      (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'setVolume':
            final dynamic raw = call.arguments['percent'];
            final num? val = raw is num ? raw : num.tryParse(raw?.toString() ?? '');
            if (val == null || val < 0 || val > 100) {
              return {
                'status': 'error',
                'action': 'set_volume',
                'previousValue': currentMockVolume,
                'targetValue': null,
                'executionLatencyMs': 2,
                'errorCode': 'INVALID_VOLUME_ARGUMENT',
                'errorMessage': 'Volume level must be a numeric value between 0 and 100.',
              };
            }
            final prev = currentMockVolume;
            currentMockVolume = val.round();
            return {
              'status': 'success',
              'action': 'set_volume',
              'previousValue': prev,
              'targetValue': currentMockVolume,
              'executionLatencyMs': 8,
              'errorCode': null,
              'errorMessage': null,
            };
          case 'getVolume':
            return {
              'status': 'success',
              'action': 'get_volume',
              'previousValue': currentMockVolume,
              'targetValue': currentMockVolume,
              'executionLatencyMs': 3,
              'errorCode': null,
              'errorMessage': null,
            };
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('triage.native_actions'), null);
  });

  test('setVolume(50) successfully sets volume and returns typed success ActionResult', () async {
    final result = await client.setVolume(50);

    expect(result.isSuccess, isTrue);
    expect(result.status, equals(ActionStatus.success));
    expect(result.action, equals('set_volume'));
    expect(result.previousValue, equals(25));
    expect(result.targetValue, equals(50));
    expect(result.executionLatencyMs, equals(8));
    expect(result.errorCode, isNull);
  });

  test('setVolume with out-of-range value returns typed INVALID_VOLUME_ARGUMENT error', () async {
    final resultNegative = await client.setVolume(-15);

    expect(resultNegative.isSuccess, isFalse);
    expect(resultNegative.status, equals(ActionStatus.error));
    expect(resultNegative.errorCode, equals('INVALID_VOLUME_ARGUMENT'));

    final resultExcess = await client.setVolume(150);
    expect(resultExcess.isSuccess, isFalse);
    expect(resultExcess.status, equals(ActionStatus.error));
    expect(resultExcess.errorCode, equals('INVALID_VOLUME_ARGUMENT'));

    final resultInvalid = await client.setVolume('not_a_number');
    expect(resultInvalid.isSuccess, isFalse);
    expect(resultInvalid.status, equals(ActionStatus.error));
    expect(resultInvalid.errorCode, equals('INVALID_VOLUME_ARGUMENT'));
  });

  test('getVolume returns current volume level and execution latency', () async {
    final result = await client.getVolume();

    expect(result.isSuccess, isTrue);
    expect(result.status, equals(ActionStatus.success));
    expect(result.action, equals('get_volume'));
    expect(result.targetValue, equals(25));
    expect(result.executionLatencyMs, equals(3));
  });

  test('rapid repeated volume adjustments resolve deterministically with strictly ordered previous/target values', () async {
    final futures = [
      client.setVolume(10),
      client.setVolume(20),
      client.setVolume(30),
      client.setVolume(40),
      client.setVolume(50),
      client.getVolume(),
    ];

    final results = await Future.wait(futures);

    expect(results.length, equals(6));
    expect(results[0].previousValue, equals(25));
    expect(results[0].targetValue, equals(10));

    expect(results[1].previousValue, equals(10));
    expect(results[1].targetValue, equals(20));

    expect(results[2].previousValue, equals(20));
    expect(results[2].targetValue, equals(30));

    expect(results[3].previousValue, equals(30));
    expect(results[3].targetValue, equals(40));

    expect(results[4].previousValue, equals(40));
    expect(results[4].targetValue, equals(50));

    // getVolume ordered at the end must read 50
    expect(results[5].targetValue, equals(50));
    expect(results[5].previousValue, equals(50));
    expect(methodCalls.length, equals(6));
  });
}
