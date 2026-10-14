import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:triage_client/triage_client.dart';
import '../actions/native_action_client.dart';
import '../outbox/local_outbox_repository.dart';

class RoutineExecutionReport {
  final RoutineDispatchEvent event;
  final String status; // 'completed', 'partial_failure', 'expired', 'already_claimed'
  final List<RoutineStepOutcome> stepOutcomes;
  final DateTime executedAt;
  final String? note;

  RoutineExecutionReport({
    required this.event,
    required this.status,
    required this.stepOutcomes,
    required this.executedAt,
    this.note,
  });
}

/// Orchestrates unattended routine execution on the phone, enforcing:
/// 1. Expiration validation (aborts if past expiresAt)
/// 2. Atomic SQLite claim (prevents duplicate execution side-effects)
/// 3. Native executor invocation (e.g. volume mute)
/// 4. Structured Acknowledgement dispatch back to Serverpod
class RoutineExecutionManager {
  final LocalOutboxRepository repository;
  final NativeActionClient actionClient;

  StreamSubscription<RoutineDispatchEvent>? _streamSubscription;
  final StreamController<RoutineExecutionReport> _reportController =
      StreamController<RoutineExecutionReport>.broadcast();

  bool _isListening = false;
  bool get isListening => _isListening;

  Stream<RoutineExecutionReport> get onReport => _reportController.stream;

  RoutineExecutionManager({
    required this.repository,
    required this.actionClient,
  });

  /// Starts listening to the Serverpod real-time WebSocket stream for routine dispatches.
  void startListening(
    Client client, {
    required String deviceId,
    required String deviceToken,
    void Function(RoutineExecutionReport)? onExecuted,
    void Function(Object error)? onError,
  }) {
    stopListening();
    _isListening = true;

    try {
      final stream = client.routine.streamRoutineDispatches(
        deviceId: deviceId,
        deviceToken: deviceToken,
      );

      _streamSubscription = stream.listen(
        (event) async {
          try {
            final report = await handleDispatchEvent(
              client,
              event: event,
              deviceId: deviceId,
              deviceToken: deviceToken,
            );
            _reportController.add(report);
            onExecuted?.call(report);
          } catch (e) {
            debugPrint('[RoutineExecutionManager] Error handling dispatch: $e');
            onError?.call(e);
          }
        },
        onError: (err) {
          debugPrint('[RoutineExecutionManager] Stream error: $err');
          _isListening = false;
          onError?.call(err);
        },
        onDone: () {
          debugPrint('[RoutineExecutionManager] Stream closed');
          _isListening = false;
        },
      );
    } catch (e) {
      _isListening = false;
      onError?.call(e);
    }
  }

  /// Handles incoming RoutineDispatchEvent following Ticket 05 guarantees:
  /// 1. Expiration check: Aborts if now > expiresAt.
  /// 2. Atomic local claim: Aborts if already claimed to prevent duplicate side-effects.
  /// 3. Step execution: Executes unattended steps (e.g. set_volume) via NativeActionClient.
  /// 4. Structured Acknowledgement: Transmits outcomes back to Serverpod.
  Future<RoutineExecutionReport> handleDispatchEvent(
    Client client, {
    required RoutineDispatchEvent event,
    required String deviceId,
    required String deviceToken,
  }) async {
    final now = DateTime.now().toUtc();

    // 1. Expiration check
    if (now.isAfter(event.expiresAt.toUtc())) {
      final ack = RoutineAcknowledgementEvent(
        routineOccurrenceId: event.routineOccurrenceId,
        routineId: event.routineId,
        deviceId: deviceId,
        deviceToken: deviceToken,
        status: 'expired',
        stepOutcomes: [],
        completedAt: now,
        clientNote:
            'Dispatch expired (received after ${event.expiresAt.toIso8601String()})',
      );
      await client.routine.acknowledgeRoutine(ack);
      return RoutineExecutionReport(
        event: event,
        status: 'expired',
        stepOutcomes: [],
        executedAt: now,
        note: 'Expired before execution',
      );
    }

    // 2. Atomic claim in SQLite
    final claimed = await repository.attemptClaimRoutineOccurrence(
      event.routineOccurrenceId,
      event.routineId,
    );

    if (!claimed) {
      // Duplicate occurrence event suppressed
      final ack = RoutineAcknowledgementEvent(
        routineOccurrenceId: event.routineOccurrenceId,
        routineId: event.routineId,
        deviceId: deviceId,
        deviceToken: deviceToken,
        status: 'already_claimed',
        stepOutcomes: [],
        completedAt: now,
        clientNote:
            'Occurrence already claimed in local SQLite; duplicate execution suppressed',
      );
      await client.routine.acknowledgeRoutine(ack);
      return RoutineExecutionReport(
        event: event,
        status: 'already_claimed',
        stepOutcomes: [],
        executedAt: now,
        note: 'Duplicate occurrence suppressed by atomic claim',
      );
    }

    // 3. Step execution via NativeActionClient
    final outcomes = <RoutineStepOutcome>[];
    List<dynamic>? rawSteps;
    String? parseError;

    try {
      final decoded = jsonDecode(event.stepsJson);
      if (decoded is List) {
        rawSteps = decoded;
      } else {
        parseError = 'stepsJson root element is not a JSON list';
      }
    } catch (e) {
      parseError = 'Failed to parse stepsJson: $e';
    }

    if (parseError != null || rawSteps == null || rawSteps.isEmpty) {
      final failureMessage = parseError ?? 'Routine contains no executable steps';
      outcomes.add(
        RoutineStepOutcome(
          stepId: 'error-steps',
          action: 'none',
          status: 'failed',
          latencyMs: 0,
          errorMessage: failureMessage,
        ),
      );
    } else {
      for (var i = 0; i < rawSteps.length; i++) {
        final step = rawSteps[i];
        if (step is! Map<String, dynamic>) {
          outcomes.add(
            RoutineStepOutcome(
              stepId: 'step-${i + 1}',
              action: 'invalid',
              status: 'failed',
              latencyMs: 0,
              errorMessage:
                  'Malformed step descriptor at index $i (expected JSON object)',
            ),
          );
          continue;
        }

        final stepId = step['stepId']?.toString() ?? 'step-${i + 1}';
        final action = step['action']?.toString() ?? '';
        final stopwatch = Stopwatch()..start();

        if (action == 'set_volume') {
          final targetValue = step['targetValue'] ?? 0;
          final res = await actionClient.setVolume(targetValue);
          stopwatch.stop();

          outcomes.add(
            RoutineStepOutcome(
              stepId: stepId,
              action: action,
              status: res.isSuccess ? 'success' : 'failed',
              latencyMs: stopwatch.elapsedMilliseconds,
              errorMessage: res.isSuccess
                  ? null
                  : (res.errorMessage ?? 'Volume execution failed'),
              actualValue: res.targetValue?.toString(),
            ),
          );
        } else {
          stopwatch.stop();
          outcomes.add(
            RoutineStepOutcome(
              stepId: stepId,
              action: action,
              status: 'failed',
              latencyMs: stopwatch.elapsedMilliseconds,
              errorMessage: 'Unsupported routine step action: $action',
            ),
          );
        }
      }
    }

    final hasFailures =
        outcomes.isEmpty || outcomes.any((o) => o.status == 'failed');
    final overallStatus = hasFailures ? 'partial_failure' : 'completed';

    // 4. Update local SQLite claim record
    await repository.updateRoutineOccurrenceOutcome(
      event.routineOccurrenceId,
      status: overallStatus,
      outcomesJson: jsonEncode(outcomes
          .map((o) => {
                'stepId': o.stepId,
                'action': o.action,
                'status': o.status,
                'latencyMs': o.latencyMs,
                'errorMessage': o.errorMessage,
                'actualValue': o.actualValue,
              })
          .toList()),
    );

    // 5. Send structured Acknowledgement back to Serverpod
    final clientNote = hasFailures
        ? outcomes
            .firstWhere(
              (o) => o.status == 'failed',
              orElse: () => outcomes.first,
            )
            .errorMessage
        : null;

    final ack = RoutineAcknowledgementEvent(
      routineOccurrenceId: event.routineOccurrenceId,
      routineId: event.routineId,
      deviceId: deviceId,
      deviceToken: deviceToken,
      status: overallStatus,
      stepOutcomes: outcomes,
      completedAt: DateTime.now().toUtc(),
      clientNote: clientNote,
    );

    await client.routine.acknowledgeRoutine(ack);

    return RoutineExecutionReport(
      event: event,
      status: overallStatus,
      stepOutcomes: outcomes,
      executedAt: DateTime.now().toUtc(),
    );
  }

  void stopListening() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _isListening = false;
  }

  void dispose() {
    stopListening();
    _reportController.close();
  }
}
