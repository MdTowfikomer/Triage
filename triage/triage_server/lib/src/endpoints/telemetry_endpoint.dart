import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';
import '../services/inbox_service.dart';

class TelemetryEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Pushes latest device telemetry snapshot to PostgreSQL.
  /// Validates user ownership and device token, updates or inserts the record,
  /// and broadcasts the update to real-time subscribers over WebSockets.
  Future<DeviceTelemetry> update(
    Session session,
    DeviceTelemetry telemetry,
    String deviceToken,
  ) async {
    final userId = InboxService.userId(session);
    final cleanDeviceId = telemetry.deviceId.trim();
    final cleanDeviceToken = deviceToken.trim();

    if (cleanDeviceId.isEmpty || cleanDeviceToken.isEmpty) {
      throw TriageException(
        code: 'invalid_input',
        message: 'Device ID and device token must be provided.',
      );
    }

    final registration = await DeviceRegistration.db.findFirstRow(
      session,
      where: (t) =>
          t.deviceId.equals(cleanDeviceId) &
          t.deviceToken.equals(cleanDeviceToken),
    );

    if (registration == null) {
      throw TriageException(
        code: 'unauthorized',
        message: 'Invalid or unregistered device token.',
      );
    }

    if (registration.userId != userId) {
      throw TriageException(
        code: 'forbidden',
        message: 'Device "$cleanDeviceId" is owned by another user account.',
      );
    }

    // Touch device registration lastSeenAt
    registration.lastSeenAt = DateTime.now().toUtc();
    await DeviceRegistration.db.updateRow(session, registration);

    final now = DateTime.now().toUtc();
    final existing = await DeviceTelemetry.db.findFirstRow(
      session,
      where: (t) => t.deviceId.equals(cleanDeviceId),
    );

    DeviceTelemetry saved;
    if (existing != null) {
      existing.batteryLevel = telemetry.batteryLevel;
      existing.isCharging = telemetry.isCharging;
      existing.volumeLevel = telemetry.volumeLevel;
      existing.brightnessLevel = telemetry.brightnessLevel;
      existing.dndEnabled = telemetry.dndEnabled;
      existing.updatedAt = now;
      saved = await DeviceTelemetry.db.updateRow(session, existing);
    } else {
      telemetry.updatedAt = now;
      saved = await DeviceTelemetry.db.insertRow(session, telemetry);
    }

    // Broadcast to WebSocket channel for remote monitoring
    await session.messages.postMessage(
      'telemetry.device.$cleanDeviceId',
      saved,
    );

    return saved;
  }

  /// Gets the latest telemetry record for a registered device owned by the authenticated user.
  Future<DeviceTelemetry?> getLatest(
    Session session,
    String deviceId,
  ) async {
    final userId = InboxService.userId(session);
    final cleanDeviceId = deviceId.trim();

    final registration = await DeviceRegistration.db.findFirstRow(
      session,
      where: (t) => t.deviceId.equals(cleanDeviceId),
    );

    if (registration == null || registration.userId != userId) {
      throw TriageException(
        code: 'forbidden',
        message: 'Access denied for device "$cleanDeviceId".',
      );
    }

    return await DeviceTelemetry.db.findFirstRow(
      session,
      where: (t) => t.deviceId.equals(cleanDeviceId),
    );
  }

  /// Real-time stream of telemetry events for a specific device.
  Stream<DeviceTelemetry> streamTelemetry(
    Session session,
    String deviceId,
  ) async* {
    final userId = InboxService.userId(session);
    final cleanDeviceId = deviceId.trim();

    final registration = await DeviceRegistration.db.findFirstRow(
      session,
      where: (t) => t.deviceId.equals(cleanDeviceId),
    );

    if (registration == null || registration.userId != userId) {
      throw TriageException(
        code: 'forbidden',
        message: 'Access denied for device "$cleanDeviceId".',
      );
    }

    final channelName = 'telemetry.device.$cleanDeviceId';
    final stream = session.messages.createStream<DeviceTelemetry>(channelName);
    await for (final update in stream) {
      yield update;
    }
  }
}
