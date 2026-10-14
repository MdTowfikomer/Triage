import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../services/inbox_service.dart';

class CommandSyncEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Synchronizes a batch of offline voice command records to PostgreSQL idempotently.
  /// Validates authenticated user session, scoped device auth token, and deduplicates entries by eventId.
  Future<VoiceCommandSyncResult> syncBatch(
    Session session,
    VoiceCommandSyncBatch batch,
  ) async {
    final userId = InboxService.userId(session);
    final cleanDeviceId = batch.deviceId.trim();
    final cleanDeviceToken = batch.deviceToken.trim();

    if (cleanDeviceId.isEmpty || cleanDeviceToken.isEmpty) {
      throw TriageException(
        code: 'invalid_input',
        message: 'Device ID and device token must be provided.',
      );
    }

    // Authenticate device token against server registrations table
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

    // Touch lastSeenAt timestamp
    registration.lastSeenAt = DateTime.now().toUtc();
    await DeviceRegistration.db.updateRow(session, registration);

    var syncedCount = 0;
    var duplicateCount = 0;
    var failedCount = 0;
    final syncedEventIds = <String>[];

    for (final entry in batch.entries) {
      final eventId = entry.eventId.trim();
      if (eventId.isEmpty) {
        failedCount++;
        continue;
      }

      // Check if record already exists (deduplication)
      final existing = await VoiceCommandLog.db.findFirstRow(
        session,
        where: (t) => t.eventId.equals(eventId),
      );

      if (existing != null) {
        if (existing.deviceId == cleanDeviceId) {
          // Acknowledge idempotent duplicate from the same registered device
          duplicateCount++;
          syncedEventIds.add(eventId);
        } else {
          // Conflict: eventId already exists for a DIFFERENT device ID
          session.log(
            'Event ID conflict: $eventId belongs to device ${existing.deviceId}, rejected for $cleanDeviceId',
            level: LogLevel.warning,
          );
          failedCount++;
        }
        continue;
      }

      try {
        final log = VoiceCommandLog(
          eventId: eventId,
          deviceId: cleanDeviceId,
          intent: entry.intent,
          actionTarget: entry.actionTarget,
          resultType: entry.resultType,
          executionLatencyMs: entry.executionLatencyMs,
          executedOffline: entry.executedOffline,
          syncedAt: DateTime.now().toUtc(),
          transcript: entry.transcript, // null unless user explicitly opted in
        );

        await VoiceCommandLog.db.insertRow(session, log);
        syncedCount++;
        syncedEventIds.add(eventId);
      } on DatabaseException catch (e) {
        // Handle concurrent duplicate write on race condition: verify device matches
        final collided = await VoiceCommandLog.db.findFirstRow(
          session,
          where: (t) => t.eventId.equals(eventId),
        );
        if (collided != null && collided.deviceId == cleanDeviceId) {
          duplicateCount++;
          syncedEventIds.add(eventId);
        } else {
          session.log(
            'Database error or conflict on eventId $eventId: $e',
            level: LogLevel.error,
          );
          failedCount++;
        }
      } catch (e) {
        session.log(
          'Failed to persist VoiceCommandLog $eventId: $e',
          level: LogLevel.error,
        );
        failedCount++;
      }
    }

    return VoiceCommandSyncResult(
      syncedCount: syncedCount,
      duplicateCount: duplicateCount,
      failedCount: failedCount,
      syncedEventIds: syncedEventIds,
    );
  }
}
