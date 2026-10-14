import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:triage_client/triage_client.dart';
import '../actions/action_result.dart';
import '../actions/native_action_client.dart';
import '../outbox/local_outbox_repository.dart';
import 'routine_execution_manager.dart';

class LocalRoutineScheduler {
  final LocalOutboxRepository repository;
  final NativeActionClient actionClient;
  final FlutterLocalNotificationsPlugin? notificationsPlugin;

  LocalRoutineScheduler({
    required this.repository,
    required this.actionClient,
    this.notificationsPlugin,
  });

  /// Mirrors a routine schedule from Serverpod down to local SQLite
  /// and registers a hardware-backed exact alarm via AlarmManager.setExactAndAllowWhileIdle().
  Future<LocalRoutineRecord> mirrorAndScheduleRoutine({
    required String routineId,
    required String occurrenceId,
    required String name,
    required DateTime scheduledTime,
    required DateTime expiresAt,
    required String stepsJson,
  }) async {
    final canExact = await actionClient.canScheduleExactAlarms();
    final status = canExact ? 'scheduled_exact' : 'scheduled_inexact';

    final record = LocalRoutineRecord(
      routineId: routineId,
      occurrenceId: occurrenceId,
      name: name,
      scheduledTime: scheduledTime,
      expiresAt: expiresAt,
      stepsJson: stepsJson,
      status: status,
    );

    await repository.saveLocalRoutine(record);

    if (canExact) {
      final epochMs = scheduledTime.toUtc().millisecondsSinceEpoch;
      await actionClient.scheduleExactAlarm(
        occurrenceId,
        epochMs,
        name: name,
      );
    }

    return record;
  }

  /// Listens for native alarm triggers and automatically executes matched routines.
  void listenToHardwareAlarms({
    Client? serverpodClient,
    String? deviceId,
    String? deviceToken,
    void Function(RoutineExecutionReport report)? onExecuted,
  }) {
    actionClient.registerAlarmHandler((occurrenceId, name) async {
      final report = await executeTriggeredRoutine(
        occurrenceId: occurrenceId,
        routineId: '', // Will resolve via occurrenceId in SQLite
        name: name.isNotEmpty ? name : null,
        serverpodClient: serverpodClient,
        deviceId: deviceId,
        deviceToken: deviceToken,
      );
      onExecuted?.call(report);
    });
  }

  /// Executes a triggered routine (invoked by either local AlarmManager OR Serverpod WebSocket).
  /// Reconciles execution atomically using SQLite UNIQUE constraint on routine_occurrence_id.
  /// Unattended steps (volume, brightness, DND) execute directly in the background.
  /// Attended steps (app launch) post a high-priority heads-up notification honoring Android BAL rules.
  Future<RoutineExecutionReport> executeTriggeredRoutine({
    required String occurrenceId,
    required String routineId,
    String? name,
    DateTime? expiresAt,
    String? stepsJson,
    Client? serverpodClient,
    String? deviceId,
    String? deviceToken,
  }) async {
    final now = DateTime.now().toUtc();

    // 1. Resolve routine details from SQLite or arguments
    LocalRoutineRecord? localRecord;
    if (routineId.isNotEmpty) {
      localRecord = await repository.getLocalRoutine(routineId);
    }
    if (localRecord == null && occurrenceId.isNotEmpty) {
      localRecord = await repository.getLocalRoutineByOccurrenceId(occurrenceId);
    }

    final effectiveRoutineId = routineId.isNotEmpty
        ? routineId
        : (localRecord?.routineId ?? 'routine_$occurrenceId');
    final effectiveName = name ?? localRecord?.name ?? 'Scheduled Routine';
    final effectiveExpiresAt = expiresAt ?? localRecord?.expiresAt ?? now.add(const Duration(minutes: 5));
    final effectiveStepsJson = stepsJson ?? localRecord?.stepsJson ?? '[]';

    final dispatchEvent = RoutineDispatchEvent(
      routineOccurrenceId: occurrenceId,
      routineId: effectiveRoutineId,
      deviceId: deviceId ?? 'local_device',
      name: effectiveName,
      scheduledTime: localRecord?.scheduledTime ?? now,
      expiresAt: effectiveExpiresAt,
      dispatchedAt: now,
      stepsJson: effectiveStepsJson,
    );

    // 2. Expiration check: Abort if now > expiresAt
    if (now.isAfter(effectiveExpiresAt.toUtc())) {
      await repository.updateLocalRoutineStatus(routineId, 'expired');
      if (serverpodClient != null && deviceId != null && deviceToken != null) {
        try {
          await serverpodClient.routine.acknowledgeRoutine(
            RoutineAcknowledgementEvent(
              routineOccurrenceId: occurrenceId,
              routineId: routineId,
              deviceId: deviceId,
              deviceToken: deviceToken,
              status: 'expired',
              stepOutcomes: [],
              completedAt: now,
              clientNote: 'Routine expired prior to trigger execution',
            ),
          );
        } catch (_) {}
      }
      return RoutineExecutionReport(
        event: dispatchEvent,
        status: 'expired',
        stepOutcomes: [],
        executedAt: now,
        note: 'Expired before execution',
      );
    }

    // 3. ATOMIC CLAIM in SQLite: First trigger wins; subsequent triggers safely abort
    final claimed = await repository.attemptClaimRoutineOccurrence(occurrenceId, routineId);
    if (!claimed) {
      if (serverpodClient != null && deviceId != null && deviceToken != null) {
        try {
          await serverpodClient.routine.acknowledgeRoutine(
            RoutineAcknowledgementEvent(
              routineOccurrenceId: occurrenceId,
              routineId: routineId,
              deviceId: deviceId,
              deviceToken: deviceToken,
              status: 'already_claimed',
              stepOutcomes: [],
              completedAt: now,
              clientNote: 'Occurrence already claimed in local SQLite; duplicate execution suppressed',
            ),
          );
        } catch (_) {}
      }
      return RoutineExecutionReport(
        event: dispatchEvent,
        status: 'already_claimed',
        stepOutcomes: [],
        executedAt: now,
        note: 'Duplicate execution suppressed by atomic claim',
      );
    }

    // 4. Step execution: Parse steps and separate unattended vs attended
    final outcomes = <RoutineStepOutcome>[];
    List<dynamic> steps = [];
    try {
      final decoded = jsonDecode(effectiveStepsJson);
      if (decoded is List) steps = decoded;
    } catch (_) {}

    if (steps.isEmpty) {
      outcomes.add(
        RoutineStepOutcome(
          stepId: 'empty_steps',
          action: 'noop',
          status: 'failed',
          latencyMs: 0,
          errorMessage: 'Routine contains no executable steps',
        ),
      );
    }

    for (final raw in steps) {
      if (raw is! Map) continue;
      final step = Map<String, dynamic>.from(raw);
      final stepId = step['stepId'] as String? ?? 'step_${outcomes.length + 1}';
      final action = step['action'] as String? ?? 'noop';
      final dynamic targetValue = step['targetValue'];
      final isUnattended = step['unattended'] == true || _isNaturallyUnattended(action);

      final startMs = DateTime.now().millisecondsSinceEpoch;

      if (isUnattended) {
        // Execute background unattended hardware action
        ActionResult result;
        switch (action) {
          case 'set_volume':
            result = await actionClient.setVolume(targetValue ?? 0, showUi: false);
            break;
          case 'set_brightness':
            result = await actionClient.setBrightness(targetValue ?? 50);
            break;
          case 'set_dnd':
            result = await actionClient.setDoNotDisturb(targetValue == true || targetValue == 1);
            break;
          default:
            result = ActionResult(
              status: ActionStatus.error,
              action: action,
              executionLatencyMs: 0,
              errorCode: 'UNSUPPORTED_UNATTENDED_ACTION',
              errorMessage: 'Action $action cannot execute unattended',
            );
        }

        final latency = DateTime.now().millisecondsSinceEpoch - startMs;
        outcomes.add(
          RoutineStepOutcome(
            stepId: stepId,
            action: action,
            status: result.isSuccess ? 'success' : 'failed',
            actualValue: result.targetValue?.toString(),
            latencyMs: latency,
            errorMessage: result.errorMessage ?? result.errorCode,
          ),
        );
      } else {
        // Attended step: Post heads-up notification honoring Android BAL restrictions
        await _postAttendedNotification(
          title: effectiveName,
          body: 'Tap to execute: $action ($stepId)',
          payload: jsonEncode(step),
        );

        final latency = DateTime.now().millisecondsSinceEpoch - startMs;
        outcomes.add(
          RoutineStepOutcome(
            stepId: stepId,
            action: action,
            status: 'handed_off',
            actualValue: 'notification_posted',
            latencyMs: latency,
          ),
        );
      }
    }

    // 5. Update local SQLite routine claim & status
    final allSucceeded = outcomes.every((o) => o.status == 'success' || o.status == 'handed_off');
    final finalStatus = allSucceeded ? 'completed' : 'partial_failure';

    await repository.updateLocalRoutineStatus(routineId, finalStatus);
    await repository.updateRoutineOccurrenceOutcome(
      occurrenceId,
      status: finalStatus,
      outcomesJson: jsonEncode(outcomes.map((o) => o.toJson()).toList()),
    );

    // 6. Transmit acknowledgement to Serverpod if connected
    if (serverpodClient != null && deviceId != null && deviceToken != null) {
      try {
        final ack = RoutineAcknowledgementEvent(
          routineOccurrenceId: occurrenceId,
          routineId: routineId,
          deviceId: deviceId,
          deviceToken: deviceToken,
          status: finalStatus,
          stepOutcomes: outcomes,
          completedAt: DateTime.now().toUtc(),
          clientNote: 'Executed via LocalRoutineScheduler ($finalStatus)',
        );
        await serverpodClient.routine.acknowledgeRoutine(ack);
      } catch (_) {}
    }

    return RoutineExecutionReport(
      event: dispatchEvent,
      status: finalStatus,
      stepOutcomes: outcomes,
      executedAt: now,
      note: 'Executed via LocalRoutineScheduler',
    );
  }

  static bool _isNaturallyUnattended(String action) {
    return action == 'set_volume' || action == 'set_brightness' || action == 'set_dnd';
  }

  Future<void> _postAttendedNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final plugin = notificationsPlugin;
    if (plugin == null) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'triage_attended_routines',
        'Routine Step Notifications',
        channelDescription: 'Heads-up notification for attended routine actions requiring user tap',
        importance: Importance.max,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);
      await plugin.show(
        id: title.hashCode,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (_) {}
  }
}
