import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

class RoutineDispatcherFutureCall extends FutureCall {
  Future<void> fire(Session session, String routineId) async {
    final now = DateTime.now().toUtc();

    // Look up scheduled routine in PostgreSQL
    final routine = await RoutineSchedule.db.findFirstRow(
      session,
      where: (t) => t.routineId.equals(routineId),
    );

    if (routine == null) {
      session.log(
        'Routine $routineId not found in database; aborting dispatch.',
        level: LogLevel.warning,
      );
      return;
    }

    // Only dispatch if still in 'scheduled' status
    if (routine.status != 'scheduled') {
      session.log(
        'Routine $routineId status is "${routine.status}"; skipping dispatch.',
        level: LogLevel.info,
      );
      return;
    }

    final occurrenceId = const Uuid().v4();
    final expiresAt = routine.scheduledTime.add(const Duration(minutes: 5));

    final event = RoutineDispatchEvent(
      routineOccurrenceId: occurrenceId,
      routineId: routine.routineId,
      deviceId: routine.deviceId,
      name: routine.name,
      stepsJson: routine.stepsJson,
      scheduledTime: routine.scheduledTime,
      expiresAt: expiresAt,
      dispatchedAt: now,
    );

    // Transition status to 'dispatched' and persist occurrenceId BEFORE posting message
    // to prevent race condition where fast client ACK arrives before dispatched status is saved
    routine.lastOccurrenceId = occurrenceId;
    routine.status = 'dispatched';
    routine.dispatchedAt = now;
    await RoutineSchedule.db.updateRow(session, routine);

    // Push event to the connected device via Serverpod WebSocket message stream
    final deviceChannel = 'triage.device.${routine.deviceId}';
    await session.messages.postMessage(deviceChannel, event);

    session.log(
      'Dispatched routine "${routine.name}" ($routineId, occurrence: $occurrenceId) to $deviceChannel',
      level: LogLevel.info,
    );
  }
}
