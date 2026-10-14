import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:test/test.dart';
import 'package:triage_server/server.dart';
import 'package:triage_server/src/generated/protocol.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Ticket 04: Device registration and outbox audit sync', (
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

    test(
      'registerDevice binds device to authenticated user ownership and returns scoped token',
      () async {
        const deviceId = 'test-device-uuid-001';
        final regResponse = await endpoints.device.registerDevice(
          authSessionA,
          deviceId,
          deviceName: 'Nothing Phone 2a',
        );

        expect(regResponse.deviceId, equals(deviceId));
        expect(regResponse.deviceToken, isNotEmpty);

        // Verify database persistence and ownership relation
        final inDb = await DeviceRegistration.db.findFirstRow(
          dbSession,
          where: (t) => t.deviceId.equals(deviceId),
        );
        expect(inDb, isNotNull);
        expect(inDb!.userId, equals(userA));
        expect(inDb.deviceToken, equals(regResponse.deviceToken));
        expect(inDb.deviceName, equals('Nothing Phone 2a'));
      },
    );

    test('authenticatePilotUser returns valid AuthSuccess session', () async {
      final auth = await endpoints.devAuth.authenticatePilotUser(
        builder,
        email: 'pilot@triage.local',
      );
      expect(auth.token, isNotEmpty);
      expect(auth.authUserId, isNotNull);
      expect(auth.authStrategy, equals('jwt'));
    });

    test('registerDevice requires authenticated user session', () async {
      // Unauthenticated session
      await expectLater(
        () => endpoints.device.registerDevice(
          builder, // no auth override
          'unauth-device',
        ),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    test('syncBatch requires authenticated session', () async {
      final batch = VoiceCommandSyncBatch(
        deviceId: 'unauth-sync-device',
        deviceToken: 'token-xyz',
        entries: [],
      );

      await expectLater(
        () => endpoints.commandSync.syncBatch(builder, batch),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    test('syncBatch rejects sync request from another user account with forbidden', () async {
      const deviceId = 'device-user-a-sync';
      final regA = await endpoints.device.registerDevice(
        authSessionA,
        deviceId,
        deviceName: 'User A Device',
      );

      final batch = VoiceCommandSyncBatch(
        deviceId: deviceId,
        deviceToken: regA.deviceToken,
        entries: [
          VoiceCommandSyncEntry(
            eventId: 'evt-forbidden-001',
            intent: 'set_volume',
            resultType: 'success',
            executedOffline: true,
            timestamp: DateTime.now().toUtc(),
            transcript: null,
          ),
        ],
      );

      // User B attempts to sync batch for User A's registered device
      await expectLater(
        () => endpoints.commandSync.syncBatch(authSessionB, batch),
        throwsA(isA<TriageException>().having((e) => e.code, 'code', 'forbidden')),
      );
    });

    test(
      'syncBatch idempotently persists records and enforces eventId uniqueness without throwing 500',
      () async {
        const deviceId = 'device-sync-test-42';
        final reg = await endpoints.device.registerDevice(
          authSessionA,
          deviceId,
          deviceName: 'Phone 2a',
        );

        final entry1 = VoiceCommandSyncEntry(
          eventId: 'evt-40-percent',
          intent: 'set_volume',
          actionTarget: 'volume',
          resultType: 'success',
          executionLatencyMs: 45,
          executedOffline: true,
          timestamp: DateTime.now().toUtc(),
          transcript: null, // default: raw transcript omitted
        );

        final entry2 = VoiceCommandSyncEntry(
          eventId: 'evt-80-percent',
          intent: 'set_volume',
          actionTarget: 'volume',
          resultType: 'success',
          executionLatencyMs: 38,
          executedOffline: true,
          timestamp: DateTime.now().toUtc(),
          transcript: null, // default: raw transcript omitted
        );

        final batch = VoiceCommandSyncBatch(
          deviceId: deviceId,
          deviceToken: reg.deviceToken,
          entries: [entry1, entry2],
        );

        // First sync submission under authenticated owner session
        final firstResult = await endpoints.commandSync.syncBatch(authSessionA, batch);
        expect(firstResult.syncedCount, equals(2));
        expect(firstResult.duplicateCount, equals(0));
        expect(firstResult.failedCount, equals(0));
        expect(firstResult.syncedEventIds, containsAll(['evt-40-percent', 'evt-80-percent']));

        // Verify records in PostgreSQL
        final logs = await VoiceCommandLog.db.find(
          dbSession,
          where: (t) => t.deviceId.equals(deviceId),
        );
        expect(logs.length, equals(2));
        expect(logs.every((l) => l.transcript == null), isTrue);
        expect(logs.every((l) => l.executedOffline == true), isTrue);

        // SECOND SUBMISSION (simulating network retry / resend of same batch)
        final retryResult = await endpoints.commandSync.syncBatch(authSessionA, batch);
        expect(retryResult.syncedCount, equals(0));
        expect(retryResult.duplicateCount, equals(2));
        expect(retryResult.failedCount, equals(0));
        expect(retryResult.syncedEventIds, containsAll(['evt-40-percent', 'evt-80-percent']));

        // Row count in PostgreSQL must remain unchanged (strictly 2, no duplicates)
        final logsAfterRetry = await VoiceCommandLog.db.find(
          dbSession,
          where: (t) => t.deviceId.equals(deviceId),
        );
        expect(logsAfterRetry.length, equals(2));
      },
    );

    test('syncBatch rejects unregistered or forged deviceToken', () async {
      final batch = VoiceCommandSyncBatch(
        deviceId: 'unregistered-device-id',
        deviceToken: 'fake-token-xyz',
        entries: [
          VoiceCommandSyncEntry(
            eventId: 'evt-fake',
            intent: 'set_volume',
            resultType: 'success',
            executedOffline: true,
            timestamp: DateTime.now().toUtc(),
            transcript: null,
          ),
        ],
      );

      await expectLater(
        () => endpoints.commandSync.syncBatch(authSessionA, batch),
        throwsA(isA<TriageException>().having((e) => e.code, 'code', 'unauthorized')),
      );
    });

    test('syncBatch stores transcript only when explicitly provided (opt-in)', () async {
      const deviceId = 'opt-in-device';
      final reg = await endpoints.device.registerDevice(
        authSessionA,
        deviceId,
        deviceName: 'Phone 2a',
      );

      final batch = VoiceCommandSyncBatch(
        deviceId: deviceId,
        deviceToken: reg.deviceToken,
        entries: [
          VoiceCommandSyncEntry(
            eventId: 'evt-opt-in',
            intent: 'set_volume',
            actionTarget: 'volume',
            resultType: 'success',
            executionLatencyMs: 32,
            executedOffline: true,
            timestamp: DateTime.now().toUtc(),
            transcript: 'Set volume to 50%', // explicitly opted-in
          ),
        ],
      );

      final res = await endpoints.commandSync.syncBatch(authSessionA, batch);
      expect(res.syncedCount, equals(1));

      final log = await VoiceCommandLog.db.findFirstRow(
        dbSession,
        where: (t) => t.eventId.equals('evt-opt-in'),
      );
      expect(log, isNotNull);
      expect(log!.transcript, equals('Set volume to 50%'));
    });

    test('registerDevice rejects registration if already owned by another user', () async {
      const deviceId = 'exclusive-device-01';
      // Register under User A
      final regA = await endpoints.device.registerDevice(
        authSessionA,
        deviceId,
        deviceName: 'User A Phone',
      );
      expect(regA.deviceToken, isNotEmpty);

      // Attempt registration of the same deviceId under User B -> MUST FAIL
      await expectLater(
        () => endpoints.device.registerDevice(
          authSessionB,
          deviceId,
          deviceName: 'User B Phone',
        ),
        throwsA(isA<TriageException>().having((e) => e.code, 'code', 'forbidden')),
      );

      // User A can rotate/re-register their own device
      final regA2 = await endpoints.device.registerDevice(
        authSessionA,
        deviceId,
        deviceName: 'User A Phone Updated',
      );
      expect(regA2.deviceToken, isNotEmpty);
      expect(regA2.deviceToken, isNot(equals(regA.deviceToken)));
    });

    test('syncBatch reports failure on cross-device eventId conflict', () async {
      const deviceIdA = 'device-a-owner';
      const deviceIdB = 'device-b-owner';

      final regA = await endpoints.device.registerDevice(
        authSessionA,
        deviceIdA,
        deviceName: 'Device A',
      );
      final regB = await endpoints.device.registerDevice(
        authSessionA,
        deviceIdB,
        deviceName: 'Device B',
      );

      // Device A syncs evt-shared
      final batchA = VoiceCommandSyncBatch(
        deviceId: deviceIdA,
        deviceToken: regA.deviceToken,
        entries: [
          VoiceCommandSyncEntry(
            eventId: 'evt-shared-123',
            intent: 'set_volume',
            resultType: 'success',
            executedOffline: true,
            timestamp: DateTime.now().toUtc(),
            transcript: null,
          ),
        ],
      );
      final resA = await endpoints.commandSync.syncBatch(authSessionA, batchA);
      expect(resA.syncedCount, equals(1));

      // Device B attempts to submit the same eventId -> Must be reported as failed conflict, NOT duplicate
      final batchB = VoiceCommandSyncBatch(
        deviceId: deviceIdB,
        deviceToken: regB.deviceToken,
        entries: [
          VoiceCommandSyncEntry(
            eventId: 'evt-shared-123',
            intent: 'set_volume',
            resultType: 'success',
            executedOffline: true,
            timestamp: DateTime.now().toUtc(),
            transcript: null,
          ),
        ],
      );
      final resB = await endpoints.commandSync.syncBatch(authSessionA, batchB);
      expect(resB.syncedCount, equals(0));
      expect(resB.duplicateCount, equals(0));
      expect(resB.failedCount, equals(1));
      expect(resB.syncedEventIds, isEmpty);
    });
  });
}
