import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../services/inbox_service.dart';

class DeviceEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Binds device identity to authenticated user ownership, returning a scoped device auth token.
  Future<DeviceRegistrationResponse> registerDevice(
    Session session,
    String deviceId, {
    String? deviceName,
  }) async {
    final cleanDeviceId = deviceId.trim();
    if (cleanDeviceId.isEmpty) {
      throw TriageException(
        code: 'invalid_input',
        message: 'Device ID cannot be empty.',
      );
    }

    // Authenticated user ID derived directly from the verified server session state
    final userId = InboxService.userId(session);
    final now = DateTime.now().toUtc();

    // Generate a secure scoped device auth token
    final deviceToken = const Uuid().v4();

    // Check if device already registered
    final existing = await DeviceRegistration.db.findFirstRow(
      session,
      where: (t) => t.deviceId.equals(cleanDeviceId),
    );

    if (existing == null) {
      final record = DeviceRegistration(
        deviceId: cleanDeviceId,
        userId: userId,
        deviceToken: deviceToken,
        deviceName: deviceName?.trim(),
        registeredAt: now,
        lastSeenAt: now,
      );
      await DeviceRegistration.db.insertRow(session, record);
    } else {
      // Reject if device is already registered to a different user account
      if (existing.userId != userId) {
        throw TriageException(
          code: 'forbidden',
          message: 'Device ID is already registered to another user account.',
        );
      }

      // Rotate token and update device details for the verified owner
      existing.deviceToken = deviceToken;
      if (deviceName != null) existing.deviceName = deviceName.trim();
      existing.lastSeenAt = now;
      await DeviceRegistration.db.updateRow(session, existing);
    }

    return DeviceRegistrationResponse(
      deviceId: cleanDeviceId,
      deviceToken: deviceToken,
      registeredAt: now,
    );
  }
}
