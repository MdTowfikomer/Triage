import 'dart:io';

import 'package:serverpod/protocol.dart' show FutureCallEntry;
import 'package:serverpod/serverpod.dart';

import '../generated/future_calls_generated_models/routine_dispatcher_future_call_fire_model.dart';
import '../generated/protocol.dart';
import '../services/inbox_service.dart';

class RoutineEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Schedules a routine for an authenticated user on a registered device.
  Future<RoutineScheduleResponse> scheduleRoutine(
    Session session, {
    required String deviceId,
    required String name,
    required DateTime scheduledTime,
    required String stepsJson,
  }) async {
    if (session.serverpod.runMode == 'production' &&
        Platform.environment['TRIAGE_CLOUD_ROUTINES_ENABLED'] != 'true') {
      throw TriageException(
        code: 'unsupported',
        message:
            'Cloud scheduled routines are unavailable on this plan. Use an on-device routine.',
      );
    }
    final userId = InboxService.userId(session);
    final cleanDeviceId = deviceId.trim();

    // Verify device registration and ownership
    final reg = await DeviceRegistration.db.findFirstRow(
      session,
      where: (t) => t.deviceId.equals(cleanDeviceId),
    );

    if (reg == null) {
      throw TriageException(
        code: 'not_found',
        message: 'Device "$cleanDeviceId" is not registered with Serverpod.',
      );
    }

    if (reg.userId != userId) {
      throw TriageException(
        code: 'forbidden',
        message: 'Device "$cleanDeviceId" is owned by another user account.',
      );
    }

    final now = DateTime.now().toUtc();
    final targetTime = scheduledTime.toUtc();
    final routineId = const Uuid().v4();

    final schedule = RoutineSchedule(
      routineId: routineId,
      deviceId: cleanDeviceId,
      userId: userId,
      name: name.trim(),
      scheduledTime: targetTime,
      stepsJson: stepsJson,
      status: 'scheduled',
      createdAt: now,
    );

    await RoutineSchedule.db.insertRow(session, schedule);

    // Schedule FutureCall via FutureCallEntry in database queue
    await FutureCallEntry.db.insertRow(
      session,
      FutureCallEntry(
        name: 'RoutineDispatcherFireFutureCall',
        serializedObject: SerializationManager.encode(
          RoutineDispatcherFutureCallFireModel(
            routineId: routineId,
          ).toJson(),
        ),
        time: targetTime,
        serverId: session.serverpod.serverId,
        identifier: 'triage.routine.$routineId',
      ),
    );

    session.log(
      'Scheduled routine "$name" ($routineId) for device $cleanDeviceId at $targetTime',
      level: LogLevel.info,
    );

    return RoutineScheduleResponse(
      routineId: routineId,
      status: 'scheduled',
      scheduledTime: targetTime,
    );
  }

  /// Connects device WebSocket to real-time routine dispatch messages.
  /// Requires authenticated session and matching device credentials.
  Stream<RoutineDispatchEvent> streamRoutineDispatches(
    Session session, {
    required String deviceId,
    required String deviceToken,
  }) async* {
    final userId = InboxService.userId(session);
    final cleanDeviceId = deviceId.trim();
    final cleanToken = deviceToken.trim();

    final reg = await DeviceRegistration.db.findFirstRow(
      session,
      where: (t) => t.deviceId.equals(cleanDeviceId),
    );

    if (reg == null || reg.deviceToken != cleanToken) {
      session.log(
        'Unauthorized stream connection attempt for device: $cleanDeviceId',
        level: LogLevel.warning,
      );
      throw TriageException(
        code: 'unauthorized',
        message: 'Invalid device credentials.',
      );
    }

    if (reg.userId != userId) {
      throw TriageException(
        code: 'forbidden',
        message: 'Device "$cleanDeviceId" is owned by another user account.',
      );
    }

    final channel = 'triage.device.$cleanDeviceId';
    session.log(
      'Device $cleanDeviceId connected to routine stream $channel',
      level: LogLevel.info,
    );

    yield* session.messages.createStream<RoutineDispatchEvent>(channel);
  }

  /// Dispatches execution acknowledgement back to Serverpod with per-step outcomes.
  /// Requires authenticated session, device ownership, occurrence verification, and valid state transitions.
  Future<bool> acknowledgeRoutine(
    Session session,
    RoutineAcknowledgementEvent ack,
  ) async {
    final userId = InboxService.userId(session);
    final cleanDeviceId = ack.deviceId.trim();
    final cleanToken = ack.deviceToken.trim();

    final reg = await DeviceRegistration.db.findFirstRow(
      session,
      where: (t) => t.deviceId.equals(cleanDeviceId),
    );

    if (reg == null || reg.deviceToken != cleanToken) {
      throw TriageException(
        code: 'unauthorized',
        message: 'Invalid device credentials for acknowledgement.',
      );
    }

    if (reg.userId != userId) {
      throw TriageException(
        code: 'forbidden',
        message: 'Device "$cleanDeviceId" is owned by another user account.',
      );
    }

    final routine = await RoutineSchedule.db.findFirstRow(
      session,
      where: (t) => t.routineId.equals(ack.routineId),
    );

    if (routine == null) {
      throw TriageException(
        code: 'not_found',
        message: 'Routine "${ack.routineId}" not found.',
      );
    }

    if (routine.deviceId != cleanDeviceId) {
      throw TriageException(
        code: 'forbidden',
        message:
            'Device "$cleanDeviceId" is not the target of routine "${ack.routineId}".',
      );
    }

    if (routine.userId != userId) {
      throw TriageException(
        code: 'forbidden',
        message: 'User does not own routine "${ack.routineId}".',
      );
    }

    // Verify occurrence ID matches dispatched occurrence
    if (routine.lastOccurrenceId == null ||
        routine.lastOccurrenceId != ack.routineOccurrenceId) {
      throw TriageException(
        code: 'stale_occurrence',
        message:
            'Occurrence ID "${ack.routineOccurrenceId}" does not match active dispatched occurrence "${routine.lastOccurrenceId}".',
      );
    }

    // Guard terminal status: Completed or partial_failure routines cannot be overwritten by late or duplicate ACKs
    if (routine.status == 'completed' || routine.status == 'partial_failure') {
      session.log(
        'Routine ${ack.routineId} is already in terminal status "${routine.status}"; duplicate ACK (${ack.status}) ignored without overwriting.',
        level: LogLevel.warning,
      );
      return true;
    }

    // Must be in dispatched status to accept terminal acknowledgement
    if (routine.status != 'dispatched') {
      throw TriageException(
        code: 'invalid_state',
        message:
            'Routine "${ack.routineId}" is in status "${routine.status}" and cannot transition to "${ack.status}".',
      );
    }

    // Validate terminal status
    final finalStatus = ack.status;
    if (finalStatus != 'completed' &&
        finalStatus != 'partial_failure' &&
        finalStatus != 'expired') {
      throw TriageException(
        code: 'invalid_status',
        message:
            'Status "$finalStatus" is not a valid terminal acknowledgement status.',
      );
    }

    routine.status = finalStatus;
    routine.completedAt = ack.completedAt.toUtc();
    if (ack.clientNote != null) {
      routine.lastError = ack.clientNote;
    }

    await RoutineSchedule.db.updateRow(session, routine);

    session.log(
      'Routine ${ack.routineId} acknowledged with status: $finalStatus (occurrence: ${ack.routineOccurrenceId})',
      level: LogLevel.info,
    );

    return true;
  }

  /// Queries status of a routine (for verification and UI state tracking).
  /// Strictly checks ownership so callers cannot inspect other users' routines.
  Future<RoutineSchedule?> getRoutine(
    Session session,
    String routineId,
  ) async {
    final userId = InboxService.userId(session);
    final routine = await RoutineSchedule.db.findFirstRow(
      session,
      where: (t) => t.routineId.equals(routineId),
    );

    if (routine == null) return null;

    if (routine.userId != userId) {
      throw TriageException(
        code: 'forbidden',
        message: 'You do not have access to routine "$routineId".',
      );
    }

    return routine;
  }
}
