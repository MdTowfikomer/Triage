import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:triage_client/triage_client.dart';
import '../actions/native_action_client.dart';

class TelemetrySnapshot {
  final int batteryLevel;
  final bool isCharging;
  final double volumeLevel;
  final double brightnessLevel;
  final bool dndEnabled;
  final DateTime timestamp;

  const TelemetrySnapshot({
    required this.batteryLevel,
    required this.isCharging,
    required this.volumeLevel,
    required this.brightnessLevel,
    required this.dndEnabled,
    required this.timestamp,
  });

  DeviceTelemetry toServerpod(String deviceId) {
    return DeviceTelemetry(
      deviceId: deviceId,
      batteryLevel: batteryLevel,
      isCharging: isCharging,
      volumeLevel: volumeLevel,
      brightnessLevel: brightnessLevel,
      dndEnabled: dndEnabled,
      updatedAt: timestamp,
    );
  }
}

class DeviceTelemetryManager {
  final NativeActionClient actionClient;
  final Battery? battery;

  StreamSubscription<BatteryState>? _batterySubscription;
  TelemetrySnapshot? _lastSnapshot;

  DeviceTelemetryManager({
    required this.actionClient,
    this.battery,
  });

  TelemetrySnapshot? get lastSnapshot => _lastSnapshot;

  /// Gathers local device telemetry snapshot from BatteryManager & native bridge
  Future<TelemetrySnapshot> collectSnapshot() async {
    final effectiveBattery = battery ?? Battery();
    final readErrors = <String>[];

    int? batteryLevel;
    bool isCharging = false;
    try {
      batteryLevel = await effectiveBattery.batteryLevel;
      final state = await effectiveBattery.batteryState;
      isCharging = (state == BatteryState.charging || state == BatteryState.full);
    } catch (e) {
      readErrors.add('battery ($e)');
    }

    double? volumeLevel;
    try {
      final volRes = await actionClient.getVolume();
      if (volRes.isSuccess && volRes.targetValue is num) {
        volumeLevel = (volRes.targetValue as num).toDouble() / 100.0;
      } else {
        readErrors.add('volume (${volRes.errorMessage ?? volRes.errorCode})');
      }
    } catch (e) {
      readErrors.add('volume ($e)');
    }

    double? brightnessLevel;
    try {
      final brightRes = await actionClient.getBrightness();
      if (brightRes.isSuccess && brightRes.targetValue is num) {
        brightnessLevel = (brightRes.targetValue as num).toDouble() / 100.0;
      } else {
        readErrors.add('brightness (${brightRes.errorMessage ?? brightRes.errorCode})');
      }
    } catch (e) {
      readErrors.add('brightness ($e)');
    }

    bool? dndEnabled;
    try {
      final dndRes = await actionClient.getDoNotDisturb();
      if (dndRes.isSuccess && dndRes.targetValue != null) {
        dndEnabled = dndRes.targetValue == 1 || dndRes.targetValue == true;
      } else {
        readErrors.add('dnd (${dndRes.errorMessage ?? dndRes.errorCode})');
      }
    } catch (e) {
      readErrors.add('dnd ($e)');
    }

    if (readErrors.isNotEmpty) {
      throw StateError(
        'Strict hardware telemetry requirement failed. Could not read: ${readErrors.join(", ")}',
      );
    }

    final snapshot = TelemetrySnapshot(
      batteryLevel: batteryLevel!,
      isCharging: isCharging,
      volumeLevel: volumeLevel!,
      brightnessLevel: brightnessLevel!,
      dndEnabled: dndEnabled!,
      timestamp: DateTime.now().toUtc(),
    );

    _lastSnapshot = snapshot;
    return snapshot;
  }

  /// Pushes latest telemetry snapshot to Serverpod backend
  Future<DeviceTelemetry> syncTelemetry(
    Client client, {
    required String deviceId,
    required String deviceToken,
  }) async {
    final snapshot = await collectSnapshot();
    final telemetry = snapshot.toServerpod(deviceId);
    return await client.telemetry.update(telemetry, deviceToken);
  }

  /// Starts listening for state changes (e.g. charger plugged/unplugged)
  void startAutoSync(
    Client client, {
    required String Function() getDeviceId,
    required String? Function() getDeviceToken,
    void Function(DeviceTelemetry telemetry)? onSynced,
    void Function(Object error)? onError,
  }) {
    stopAutoSync();
    final effectiveBattery = battery ?? Battery();
    try {
      _batterySubscription = effectiveBattery.onBatteryStateChanged.listen((state) async {
        final token = getDeviceToken();
        if (token == null || token.isEmpty) return;
        try {
          final res = await syncTelemetry(
            client,
            deviceId: getDeviceId(),
            deviceToken: token,
          );
          onSynced?.call(res);
        } catch (e) {
          onError?.call(e);
        }
      });
    } catch (_) {}
  }

  void stopAutoSync() {
    _batterySubscription?.cancel();
    _batterySubscription = null;
  }

  void dispose() {
    stopAutoSync();
  }
}
