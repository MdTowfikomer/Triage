import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:triage_flutter/actions/native_action_client.dart';
import 'package:triage_flutter/outbox/local_outbox_repository.dart';
import 'package:triage_flutter/routines/local_routine_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalRoutineScheduler Tests (Ticket 10)', () {
    late LocalOutboxRepository repository;
    late NativeActionClient actionClient;
    late LocalRoutineScheduler scheduler;
    final List<MethodCall> nativeCalls = [];

    setUp(() async {
      nativeCalls.clear();
      repository = LocalOutboxRepository();
      final inMemoryDb = sqlite3.openInMemory();
      await repository.initialize(customDb: inMemoryDb);

      actionClient = NativeActionClient();
      scheduler = LocalRoutineScheduler(
        repository: repository,
        actionClient: actionClient,
      );

      // Mock NativeActionBridge channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('triage.native_actions'),
        (MethodCall call) async {
          nativeCalls.add(call);
          switch (call.method) {
            case 'canScheduleExactAlarms':
              return true;
            case 'scheduleExactAlarm':
              return {
                'status': 'success',
                'action': 'schedule_exact_alarm',
                'targetValue': call.arguments['epochMs'],
                'executionLatencyMs': 5,
              };
            case 'cancelExactAlarm':
              return {
                'status': 'success',
                'action': 'cancel_exact_alarm',
              };
            case 'setVolume':
              return {
                'status': 'success',
                'action': 'set_volume',
                'previousValue': 20,
                'targetValue': call.arguments['percent'],
                'executionLatencyMs': 10,
              };
            case 'setBrightness':
              return {
                'status': 'success',
                'action': 'set_brightness',
                'previousValue': 30,
                'targetValue': call.arguments['percent'],
                'executionLatencyMs': 12,
              };
            case 'setDoNotDisturb':
              return {
                'status': 'success',
                'action': 'set_dnd',
                'previousValue': 0,
                'targetValue': call.arguments['enabled'] == true ? 1 : 0,
                'executionLatencyMs': 15,
              };
            default:
              return null;
          }
        },
      );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('triage.native_actions'),
        null,
      );
      await repository.dispose();
    });

    test('mirrors routine schedule to SQLite and registers exact alarm with AlarmManager', () async {
      final scheduledTime = DateTime.now().toUtc().add(const Duration(minutes: 2));
      final expiresAt = scheduledTime.add(const Duration(minutes: 5));
      final stepsJson = jsonEncode([
        {'stepId': 's1', 'action': 'set_volume', 'targetValue': 0, 'unattended': true}
      ]);

      final record = await scheduler.mirrorAndScheduleRoutine(
        routineId: 'routine-101',
        occurrenceId: 'occ-101',
        name: 'Doze Mute Routine',
        scheduledTime: scheduledTime,
        expiresAt: expiresAt,
        stepsJson: stepsJson,
      );

      expect(record.routineId, equals('routine-101'));
      expect(record.status, equals('scheduled_exact'));

      // Verify row in SQLite
      final inDb = await repository.getLocalRoutine('routine-101');
      expect(inDb, isNotNull);
      expect(inDb!.occurrenceId, equals('occ-101'));
      expect(inDb.name, equals('Doze Mute Routine'));

      // Verify AlarmManager native registration
      expect(nativeCalls.any((c) => c.method == 'scheduleExactAlarm'), isTrue);
      final alarmCall = nativeCalls.firstWhere((c) => c.method == 'scheduleExactAlarm');
      expect(alarmCall.arguments['occurrenceId'], equals('occ-101'));
      expect(alarmCall.arguments['name'], equals('Doze Mute Routine'));
    });

    test('atomic claim reconciles execution and suppresses duplicate invocation (Alarm vs WebSocket race)', () async {
      const occurrenceId = 'race-occurrence-xyz';
      const routineId = 'race-routine-123';
      final stepsJson = jsonEncode([
        {'stepId': 'step-vol', 'action': 'set_volume', 'targetValue': 30, 'unattended': true}
      ]);

      // Trigger 1: Local exact alarm fires first
      final report1 = await scheduler.executeTriggeredRoutine(
        occurrenceId: occurrenceId,
        routineId: routineId,
        name: 'Race Test Routine',
        stepsJson: stepsJson,
      );

      expect(report1.status, equals('completed'));
      expect(report1.stepOutcomes.first.status, equals('success'));
      expect(nativeCalls.where((c) => c.method == 'setVolume').length, equals(1));

      // Trigger 2: WebSocket push arrives shortly after with the same occurrenceId
      final report2 = await scheduler.executeTriggeredRoutine(
        occurrenceId: occurrenceId,
        routineId: routineId,
        name: 'Race Test Routine',
        stepsJson: stepsJson,
      );

      // Must be safely suppressed by atomic SQLite claim!
      expect(report2.status, equals('already_claimed'));
      expect(report2.note, contains('Duplicate execution suppressed'));

      // Hardware setVolume was NOT invoked a second time!
      expect(nativeCalls.where((c) => c.method == 'setVolume').length, equals(1));
    });

    test('executes unattended steps directly in background (volume, brightness, DND)', () async {
      const occurrenceId = 'unattended-occ-1';
      const routineId = 'unattended-rout-1';
      final stepsJson = jsonEncode([
        {'stepId': 'v1', 'action': 'set_volume', 'targetValue': 0, 'unattended': true},
        {'stepId': 'b1', 'action': 'set_brightness', 'targetValue': 20, 'unattended': true},
        {'stepId': 'd1', 'action': 'set_dnd', 'targetValue': 1, 'unattended': true},
      ]);

      final report = await scheduler.executeTriggeredRoutine(
        occurrenceId: occurrenceId,
        routineId: routineId,
        stepsJson: stepsJson,
      );

      expect(report.status, equals('completed'));
      expect(report.stepOutcomes.length, equals(3));
      expect(report.stepOutcomes.every((s) => s.status == 'success'), isTrue);

      expect(nativeCalls.any((c) => c.method == 'setVolume'), isTrue);
      expect(nativeCalls.any((c) => c.method == 'setBrightness'), isTrue);
      expect(nativeCalls.any((c) => c.method == 'setDoNotDisturb'), isTrue);
    });

    test('hands off attended steps via notification without crashing background thread', () async {
      const occurrenceId = 'attended-occ-2';
      const routineId = 'attended-rout-2';
      final stepsJson = jsonEncode([
        {'stepId': 'app1', 'action': 'open_app', 'targetValue': 'camera', 'unattended': false},
      ]);

      final report = await scheduler.executeTriggeredRoutine(
        occurrenceId: occurrenceId,
        routineId: routineId,
        stepsJson: stepsJson,
      );

      expect(report.status, equals('completed'));
      expect(report.stepOutcomes.first.status, equals('handed_off'));
      expect(report.stepOutcomes.first.actualValue, equals('notification_posted'));
    });

    test('marks expired routines without executing hardware side effects', () async {
      const occurrenceId = 'expired-occ-3';
      const routineId = 'expired-rout-3';
      final stepsJson = jsonEncode([
        {'stepId': 'v-late', 'action': 'set_volume', 'targetValue': 100, 'unattended': true},
      ]);

      // Expired 10 minutes ago
      final pastExpiry = DateTime.now().toUtc().subtract(const Duration(minutes: 10));

      final report = await scheduler.executeTriggeredRoutine(
        occurrenceId: occurrenceId,
        routineId: routineId,
        expiresAt: pastExpiry,
        stepsJson: stepsJson,
      );

      expect(report.status, equals('expired'));
      expect(report.stepOutcomes.isEmpty, isTrue);

      // Hardware action must NOT have been called
      expect(nativeCalls.any((c) => c.method == 'setVolume'), isFalse);
    });
  });
}
