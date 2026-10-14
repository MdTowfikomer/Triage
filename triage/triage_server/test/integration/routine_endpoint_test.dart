import 'package:serverpod/protocol.dart' show FutureCallEntry;
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:test/test.dart';
import 'package:triage_server/server.dart';
import 'package:triage_server/src/future_calls/routine_dispatcher_future_call.dart';
import 'package:triage_server/src/generated/protocol.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Ticket 05: Connected routine delivery and acknowledgement', (
    builder,
    endpoints,
  ) {
    late TestSessionBuilder authSessionA;
    late TestSessionBuilder authSessionB;
    late UuidValue userA;
    late UuidValue userB;
    late Session dbSession;

    setUp(() async {
      dbSession = builder.build();
      configureAuthentication(dbSession.serverpod);

      userA = (await AuthServices.instance.authUsers.create(dbSession)).id;
      authSessionA = builder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(
          userA.toString(),
          {},
        ),
      );

      userB = (await AuthServices.instance.authUsers.create(dbSession)).id;
      authSessionB = builder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(
          userB.toString(),
          {},
        ),
      );
    });

    test('scheduleRoutine requires authenticated session', () async {
      final future = endpoints.routine.scheduleRoutine(
        builder, // Unauthenticated session builder
        deviceId: 'device-unauth-001',
        name: 'Mute volume',
        scheduledTime: DateTime.now().add(const Duration(seconds: 10)),
        stepsJson: '[]',
      );

      await expectLater(
        future,
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    test('scheduleRoutine rejects scheduling for an unregistered device', () async {
      final future = endpoints.routine.scheduleRoutine(
        authSessionA,
        deviceId: 'unregistered-device-001',
        name: 'Mute volume',
        scheduledTime: DateTime.now().add(const Duration(seconds: 10)),
        stepsJson: '[]',
      );

      await expectLater(
        future,
        throwsA(
          isA<TriageException>().having(
            (e) => e.code,
            'code',
            equals('not_found'),
          ),
        ),
      );
    });

    test('scheduleRoutine rejects scheduling for a device owned by another user', () async {
      const deviceId = 'device-owned-by-user-b';
      await endpoints.device.registerDevice(
        authSessionB,
        deviceId,
        deviceName: 'User B Phone',
      );

      final future = endpoints.routine.scheduleRoutine(
        authSessionA,
        deviceId: deviceId,
        name: 'Malicious Mute Routine',
        scheduledTime: DateTime.now().add(const Duration(seconds: 10)),
        stepsJson: '[]',
      );

      await expectLater(
        future,
        throwsA(
          isA<TriageException>().having(
            (e) => e.code,
            'code',
            equals('forbidden'),
          ),
        ),
      );
    });

    test('scheduleRoutine persists RoutineSchedule and FutureCallEntry for verified owner', () async {
      const deviceId = 'device-owner-a-001';
      await endpoints.device.registerDevice(
        authSessionA,
        deviceId,
        deviceName: 'User A Phone',
      );

      final scheduledTime = DateTime.now().toUtc().add(const Duration(seconds: 10));
      const stepsJson = '[{"stepId":"s1","action":"set_volume","targetValue":0,"unattended":true}]';

      final response = await endpoints.routine.scheduleRoutine(
        authSessionA,
        deviceId: deviceId,
        name: 'Meeting Prep: Set volume to 0%',
        scheduledTime: scheduledTime,
        stepsJson: stepsJson,
      );

      expect(response.routineId, isNotEmpty);
      expect(response.status, equals('scheduled'));

      final inDb = await RoutineSchedule.db.findFirstRow(
        dbSession,
        where: (t) => t.routineId.equals(response.routineId),
      );
      expect(inDb, isNotNull);
      expect(inDb!.userId, equals(userA));
      expect(inDb.deviceId, equals(deviceId));
      expect(inDb.status, equals('scheduled'));
      expect(inDb.stepsJson, equals(stepsJson));

      final futureCall = await FutureCallEntry.db.findFirstRow(
        dbSession,
        where: (t) => t.identifier.equals('triage.routine.${response.routineId}'),
      );
      expect(futureCall, isNotNull);
      expect(futureCall!.name, equals('RoutineDispatcherFireFutureCall'));
    });

    test('RoutineDispatcherFutureCall persists occurrenceId and dispatched status before message post', () async {
      const deviceId = 'device-dispatch-test-001';
      await endpoints.device.registerDevice(
        authSessionA,
        deviceId,
        deviceName: 'Test Phone',
      );

      final scheduledTime = DateTime.now().toUtc();
      const stepsJson = '[{"stepId":"step-1","action":"set_volume","targetValue":0}]';

      final response = await endpoints.routine.scheduleRoutine(
        authSessionA,
        deviceId: deviceId,
        name: 'Test Dispatch Routine',
        scheduledTime: scheduledTime,
        stepsJson: stepsJson,
      );

      // Execute FutureCall worker directly
      final futureCallWorker = RoutineDispatcherFutureCall();
      await futureCallWorker.fire(dbSession, response.routineId);

      // Verify routine status transitioned to 'dispatched' and lastOccurrenceId persisted
      final updated = await RoutineSchedule.db.findFirstRow(
        dbSession,
        where: (t) => t.routineId.equals(response.routineId),
      );
      expect(updated, isNotNull);
      expect(updated!.status, equals('dispatched'));
      expect(updated.dispatchedAt, isNotNull);
      expect(updated.lastOccurrenceId, isNotNull);
      expect(updated.lastOccurrenceId, isNotEmpty);
    });

    test('getRoutine enforces authentication and owner isolation', () async {
      const deviceId = 'device-get-test-001';
      await endpoints.device.registerDevice(
        authSessionA,
        deviceId,
      );

      final sched = await endpoints.routine.scheduleRoutine(
        authSessionA,
        deviceId: deviceId,
        name: 'Owner Check Routine',
        scheduledTime: DateTime.now().toUtc(),
        stepsJson: '[]',
      );

      // Unauthenticated caller is rejected by requireLogin
      await expectLater(
        endpoints.routine.getRoutine(builder, sched.routineId),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );

      // Another authenticated user (User B) is rejected with forbidden
      await expectLater(
        endpoints.routine.getRoutine(authSessionB, sched.routineId),
        throwsA(
          isA<TriageException>().having(
            (e) => e.code,
            'code',
            equals('forbidden'),
          ),
        ),
      );

      // Verified owner (User A) successfully queries routine
      final fetched = await endpoints.routine.getRoutine(authSessionA, sched.routineId);
      expect(fetched, isNotNull);
      expect(fetched!.routineId, equals(sched.routineId));
      expect(fetched.name, equals('Owner Check Routine'));
    });

    test('acknowledgeRoutine requires authenticated session', () async {
      final ack = RoutineAcknowledgementEvent(
        routineOccurrenceId: 'occ-unauth-001',
        routineId: 'some-routine-id',
        deviceId: 'dev-001',
        deviceToken: 'token-001',
        status: 'completed',
        stepOutcomes: [],
        completedAt: DateTime.now().toUtc(),
      );

      await expectLater(
        endpoints.routine.acknowledgeRoutine(builder, ack),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    test('acknowledgeRoutine rejects acknowledgement from another user account', () async {
      const deviceId = 'device-user-a-ack';
      final regA = await endpoints.device.registerDevice(
        authSessionA,
        deviceId,
      );

      final sched = await endpoints.routine.scheduleRoutine(
        authSessionA,
        deviceId: deviceId,
        name: 'User A Routine',
        scheduledTime: DateTime.now().toUtc(),
        stepsJson: '[]',
      );

      await RoutineDispatcherFutureCall().fire(dbSession, sched.routineId);
      final dispatched = await RoutineSchedule.db.findFirstRow(
        dbSession,
        where: (t) => t.routineId.equals(sched.routineId),
      );

      final ack = RoutineAcknowledgementEvent(
        routineOccurrenceId: dispatched!.lastOccurrenceId!,
        routineId: sched.routineId,
        deviceId: deviceId,
        deviceToken: regA.deviceToken,
        status: 'completed',
        stepOutcomes: [],
        completedAt: DateTime.now().toUtc(),
      );

      // User B attempts to acknowledge User A's routine
      await expectLater(
        endpoints.routine.acknowledgeRoutine(authSessionB, ack),
        throwsA(
          isA<TriageException>().having(
            (e) => e.code,
            'code',
            equals('forbidden'),
          ),
        ),
      );
    });

    test('acknowledgeRoutine rejects acknowledgement with mismatched or stale occurrence ID', () async {
      const deviceId = 'device-occ-mismatch';
      final regA = await endpoints.device.registerDevice(
        authSessionA,
        deviceId,
      );

      final sched = await endpoints.routine.scheduleRoutine(
        authSessionA,
        deviceId: deviceId,
        name: 'Occurrence Check Routine',
        scheduledTime: DateTime.now().toUtc(),
        stepsJson: '[]',
      );

      await RoutineDispatcherFutureCall().fire(dbSession, sched.routineId);

      final staleAck = RoutineAcknowledgementEvent(
        routineOccurrenceId: 'stale-fabricated-occurrence-uuid',
        routineId: sched.routineId,
        deviceId: deviceId,
        deviceToken: regA.deviceToken,
        status: 'completed',
        stepOutcomes: [],
        completedAt: DateTime.now().toUtc(),
      );

      await expectLater(
        endpoints.routine.acknowledgeRoutine(authSessionA, staleAck),
        throwsA(
          isA<TriageException>().having(
            (e) => e.code,
            'code',
            equals('stale_occurrence'),
          ),
        ),
      );
    });

    test('acknowledgeRoutine rejects acknowledgement if routine is still in scheduled status', () async {
      const deviceId = 'device-scheduled-state';
      final regA = await endpoints.device.registerDevice(
        authSessionA,
        deviceId,
      );

      final sched = await endpoints.routine.scheduleRoutine(
        authSessionA,
        deviceId: deviceId,
        name: 'Premature ACK Routine',
        scheduledTime: DateTime.now().toUtc(),
        stepsJson: '[]',
      );

      final prematureAck = RoutineAcknowledgementEvent(
        routineOccurrenceId: 'dummy-occ-123',
        routineId: sched.routineId,
        deviceId: deviceId,
        deviceToken: regA.deviceToken,
        status: 'completed',
        stepOutcomes: [],
        completedAt: DateTime.now().toUtc(),
      );

      await expectLater(
        endpoints.routine.acknowledgeRoutine(authSessionA, prematureAck),
        throwsA(
          isA<TriageException>().having(
            (e) => e.code,
            'code',
            equals('stale_occurrence'),
          ),
        ),
      );
    });

    test('acknowledgeRoutine transitions dispatched routine to completed for verified occurrence', () async {
      const deviceId = 'device-ack-completed-001';
      final regA = await endpoints.device.registerDevice(
        authSessionA,
        deviceId,
      );

      final sched = await endpoints.routine.scheduleRoutine(
        authSessionA,
        deviceId: deviceId,
        name: 'Complete Verified Test',
        scheduledTime: DateTime.now().toUtc(),
        stepsJson: '[]',
      );

      await RoutineDispatcherFutureCall().fire(dbSession, sched.routineId);
      final dispatched = await RoutineSchedule.db.findFirstRow(
        dbSession,
        where: (t) => t.routineId.equals(sched.routineId),
      );
      final validOccurrenceId = dispatched!.lastOccurrenceId!;

      final ack = RoutineAcknowledgementEvent(
        routineOccurrenceId: validOccurrenceId,
        routineId: sched.routineId,
        deviceId: deviceId,
        deviceToken: regA.deviceToken,
        status: 'completed',
        stepOutcomes: [
          RoutineStepOutcome(
            stepId: 'step-1',
            action: 'set_volume',
            status: 'success',
            latencyMs: 14,
            actualValue: '0',
          ),
        ],
        completedAt: DateTime.now().toUtc(),
      );

      final res = await endpoints.routine.acknowledgeRoutine(authSessionA, ack);
      expect(res, isTrue);

      final inDb = await RoutineSchedule.db.findFirstRow(
        dbSession,
        where: (t) => t.routineId.equals(sched.routineId),
      );
      expect(inDb!.status, equals('completed'));
      expect(inDb.completedAt, isNotNull);
    });

    test('acknowledgeRoutine records partial_failure when client step fails', () async {
      const deviceId = 'device-ack-partial-fail';
      final regA = await endpoints.device.registerDevice(
        authSessionA,
        deviceId,
      );

      final sched = await endpoints.routine.scheduleRoutine(
        authSessionA,
        deviceId: deviceId,
        name: 'Failure Record Routine',
        scheduledTime: DateTime.now().toUtc(),
        stepsJson: '[]',
      );

      await RoutineDispatcherFutureCall().fire(dbSession, sched.routineId);
      final dispatched = await RoutineSchedule.db.findFirstRow(
        dbSession,
        where: (t) => t.routineId.equals(sched.routineId),
      );

      final ack = RoutineAcknowledgementEvent(
        routineOccurrenceId: dispatched!.lastOccurrenceId!,
        routineId: sched.routineId,
        deviceId: deviceId,
        deviceToken: regA.deviceToken,
        status: 'partial_failure',
        stepOutcomes: [
          RoutineStepOutcome(
            stepId: 'step-1',
            action: 'set_volume',
            status: 'failed',
            latencyMs: 15,
            errorMessage: 'Hardware volume bridge exception',
          ),
        ],
        completedAt: DateTime.now().toUtc(),
        clientNote: 'Hardware volume bridge exception',
      );

      final res = await endpoints.routine.acknowledgeRoutine(authSessionA, ack);
      expect(res, isTrue);

      final updated = await RoutineSchedule.db.findFirstRow(
        dbSession,
        where: (t) => t.routineId.equals(sched.routineId),
      );
      expect(updated!.status, equals('partial_failure'));
      expect(updated.lastError, contains('Hardware volume bridge exception'));
    });

    test('acknowledgeRoutine preserves terminal completed status when duplicate ACK arrives', () async {
      const deviceId = 'device-duplicate-ack-test';
      final regA = await endpoints.device.registerDevice(
        authSessionA,
        deviceId,
      );

      final sched = await endpoints.routine.scheduleRoutine(
        authSessionA,
        deviceId: deviceId,
        name: 'Duplicate ACK Routine',
        scheduledTime: DateTime.now().toUtc(),
        stepsJson: '[]',
      );

      await RoutineDispatcherFutureCall().fire(dbSession, sched.routineId);
      final dispatched = await RoutineSchedule.db.findFirstRow(
        dbSession,
        where: (t) => t.routineId.equals(sched.routineId),
      );
      final occurrenceId = dispatched!.lastOccurrenceId!;

      // 1. Initial successful acknowledgement
      final successAck = RoutineAcknowledgementEvent(
        routineOccurrenceId: occurrenceId,
        routineId: sched.routineId,
        deviceId: deviceId,
        deviceToken: regA.deviceToken,
        status: 'completed',
        stepOutcomes: [],
        completedAt: DateTime.now().toUtc(),
      );
      await endpoints.routine.acknowledgeRoutine(authSessionA, successAck);

      // 2. Duplicate retry acknowledgement with 'already_claimed' status arrives later
      final duplicateAck = RoutineAcknowledgementEvent(
        routineOccurrenceId: occurrenceId,
        routineId: sched.routineId,
        deviceId: deviceId,
        deviceToken: regA.deviceToken,
        status: 'already_claimed',
        stepOutcomes: [],
        completedAt: DateTime.now().toUtc(),
        clientNote: 'Duplicate execution suppressed by atomic claim',
      );
      final dupResult = await endpoints.routine.acknowledgeRoutine(authSessionA, duplicateAck);
      expect(dupResult, isTrue);

      // Verify that status remained 'completed' and did NOT regress to 'already_claimed'
      final inDb = await RoutineSchedule.db.findFirstRow(
        dbSession,
        where: (t) => t.routineId.equals(sched.routineId),
      );
      expect(inDb!.status, equals('completed'));
    });
  });
}
