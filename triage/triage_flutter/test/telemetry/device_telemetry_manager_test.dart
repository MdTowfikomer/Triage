import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triage_flutter/actions/native_action_client.dart';
import 'package:triage_flutter/telemetry/device_telemetry_manager.dart';

class MockBattery implements Battery {
  final int mockLevel;
  final BatteryState mockState;

  MockBattery({this.mockLevel = 84, this.mockState = BatteryState.charging});

  @override
  Future<int> get batteryLevel async => mockLevel;

  @override
  Future<BatteryState> get batteryState async => mockState;

  @override
  Stream<BatteryState> get onBatteryStateChanged => Stream.value(mockState);

  @override
  Future<bool> get isInBatterySaveMode async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceTelemetryManager Tests (Ticket 09)', () {
    late NativeActionClient actionClient;
    late MockBattery mockBattery;
    late DeviceTelemetryManager telemetryManager;

    setUp(() {
      actionClient = NativeActionClient();
      mockBattery = MockBattery(mockLevel: 75, mockState: BatteryState.charging);
      telemetryManager = DeviceTelemetryManager(
        actionClient: actionClient,
        battery: mockBattery,
      );

      // Mock NativeActionBridge channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('triage.native_actions'),
        (MethodCall call) async {
          switch (call.method) {
            case 'getVolume':
              return {
                'status': 'success',
                'action': 'get_volume',
                'previousValue': null,
                'targetValue': 60,
                'executionLatencyMs': 5,
              };
            case 'getBrightness':
              return {
                'status': 'success',
                'action': 'get_brightness',
                'previousValue': null,
                'targetValue': 70,
                'executionLatencyMs': 8,
              };
            case 'getDoNotDisturb':
              return {
                'status': 'success',
                'action': 'get_dnd',
                'previousValue': null,
                'targetValue': 1,
                'executionLatencyMs': 6,
              };
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('triage.native_actions'),
        null,
      );
    });

    test('collectSnapshot gathers battery, volume, brightness, and DND states accurately', () async {
      final snapshot = await telemetryManager.collectSnapshot();

      expect(snapshot.batteryLevel, equals(75));
      expect(snapshot.isCharging, isTrue);
      expect(snapshot.volumeLevel, equals(0.60));
      expect(snapshot.brightnessLevel, equals(0.70));
      expect(snapshot.dndEnabled, isTrue);
      expect(snapshot.timestamp, isNotNull);

      final spModel = snapshot.toServerpod('device-nothing-phone-2a');
      expect(spModel.deviceId, equals('device-nothing-phone-2a'));
      expect(spModel.batteryLevel, equals(75));
      expect(spModel.isCharging, isTrue);
      expect(spModel.volumeLevel, equals(0.60));
      expect(spModel.brightnessLevel, equals(0.70));
      expect(spModel.dndEnabled, isTrue);
    });
  });
}
