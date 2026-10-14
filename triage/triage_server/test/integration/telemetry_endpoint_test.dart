import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:test/test.dart';
import 'package:triage_server/server.dart';
import 'package:triage_server/src/generated/protocol.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Ticket 09: Live device telemetry sync', (
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

    test('telemetry.update upserts record in PostgreSQL and touches lastSeenAt', () async {
      const deviceId = 'test-telemetry-dev-1';
      final reg = await endpoints.device.registerDevice(
        authSessionA,
        deviceId,
        deviceName: 'Nothing Phone 2a',
      );

      final telemetry = DeviceTelemetry(
        deviceId: deviceId,
        batteryLevel: 88,
        isCharging: true,
        volumeLevel: 0.75,
        brightnessLevel: 0.60,
        dndEnabled: true,
        updatedAt: DateTime.now().toUtc(),
      );

      final saved = await endpoints.telemetry.update(
        authSessionA,
        telemetry,
        reg.deviceToken,
      );

      expect(saved.id, isNotNull);
      expect(saved.deviceId, equals(deviceId));
      expect(saved.batteryLevel, equals(88));
      expect(saved.isCharging, isTrue);
      expect(saved.volumeLevel, equals(0.75));

      // Verify row in database
      final inDb = await DeviceTelemetry.db.findFirstRow(
        dbSession,
        where: (t) => t.deviceId.equals(deviceId),
      );
      expect(inDb, isNotNull);
      expect(inDb!.batteryLevel, equals(88));
      expect(inDb.dndEnabled, isTrue);

      // Verify second update modifies existing record rather than duplicating
      telemetry.batteryLevel = 87;
      telemetry.isCharging = false;
      await endpoints.telemetry.update(
        authSessionA,
        telemetry,
        reg.deviceToken,
      );

      final count = await DeviceTelemetry.db.count(
        dbSession,
        where: (t) => t.deviceId.equals(deviceId),
      );
      expect(count, equals(1));

      final updatedDb = await DeviceTelemetry.db.findFirstRow(
        dbSession,
        where: (t) => t.deviceId.equals(deviceId),
      );
      expect(updatedDb!.batteryLevel, equals(87));
      expect(updatedDb.isCharging, isFalse);
    });

    test('telemetry.update rejects cross-account device access with forbidden', () async {
      const deviceId = 'test-telemetry-dev-owned-by-a';
      final reg = await endpoints.device.registerDevice(
        authSessionA,
        deviceId,
        deviceName: 'Phone A',
      );

      final telemetry = DeviceTelemetry(
        deviceId: deviceId,
        batteryLevel: 50,
        isCharging: false,
        volumeLevel: 0.5,
        brightnessLevel: 0.5,
        dndEnabled: false,
        updatedAt: DateTime.now().toUtc(),
      );

      expect(
        () => endpoints.telemetry.update(
          authSessionB, // User B trying to push telemetry for Device A
          telemetry,
          reg.deviceToken,
        ),
        throwsA(isA<TriageException>().having((e) => e.code, 'code', equals('forbidden'))),
      );
    });
  });
}
