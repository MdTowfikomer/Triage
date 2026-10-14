import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:triage_client/triage_client.dart';
import 'package:triage_flutter/outbox/local_outbox_repository.dart';
import 'package:triage_flutter/outbox/outbox_event.dart';
import 'package:triage_flutter/outbox/outbox_sync_manager.dart';

class _FakeDeviceEndpoint extends Fake implements EndpointDevice {
  final Map<String, String> registeredTokens = {};

  @override
  Future<DeviceRegistrationResponse> registerDevice(
    String deviceId, {
    String? deviceName,
  }) async {
    final token = 'token-for-$deviceId';
    registeredTokens[deviceId] = token;
    return DeviceRegistrationResponse(
      deviceId: deviceId,
      deviceToken: token,
      registeredAt: DateTime.now().toUtc(),
    );
  }
}

class _FakeCommandSyncEndpoint extends Fake implements EndpointCommandSync {
  VoiceCommandSyncBatch? lastBatch;
  final Set<String> storedEventIds = {};

  @override
  Future<VoiceCommandSyncResult> syncBatch(VoiceCommandSyncBatch batch) async {
    lastBatch = batch;
    var synced = 0;
    var duplicates = 0;
    final syncedIds = <String>[];

    for (final entry in batch.entries) {
      if (storedEventIds.contains(entry.eventId)) {
        duplicates++;
        syncedIds.add(entry.eventId);
      } else {
        storedEventIds.add(entry.eventId);
        synced++;
        syncedIds.add(entry.eventId);
      }
    }

    return VoiceCommandSyncResult(
      syncedCount: synced,
      duplicateCount: duplicates,
      failedCount: 0,
      syncedEventIds: syncedIds,
    );
  }
}

class _FakeClient extends Fake implements Client {
  final fakeDevice = _FakeDeviceEndpoint();
  final fakeCommandSync = _FakeCommandSyncEndpoint();

  @override
  EndpointDevice get device => fakeDevice;

  @override
  EndpointCommandSync get commandSync => fakeCommandSync;
}

void main() {
  late LocalOutboxRepository repository;
  late SharedPreferences preferences;
  late OutboxSyncManager syncManager;
  late _FakeClient fakeClient;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = LocalOutboxRepository();
    final inMemoryDb = sqlite3.openInMemory();
    await repository.initialize(customDb: inMemoryDb);
    syncManager = OutboxSyncManager(
      repository: repository,
      preferences: preferences,
    );
    fakeClient = _FakeClient();
  });

  tearDown(() async {
    await repository.dispose();
  });

  group('OutboxSyncManager Unit Tests', () {
    test('deviceId is persistent across calls', () {
      final id1 = syncManager.deviceId;
      final id2 = syncManager.deviceId;
      expect(id1, isNotEmpty);
      expect(id1, equals(id2));
    });

    test('registerDevice obtains and persists scoped token with user binding', () async {
      expect(syncManager.isRegistered, isFalse);
      final response = await syncManager.registerDevice(
        fakeClient,
        userId: 'user-001',
        deviceName: 'A015 Phone',
      );

      expect(response.deviceId, equals(syncManager.deviceId));
      expect(syncManager.isRegistered, isTrue);
      expect(syncManager.registeredUserId, equals('user-001'));
      expect(syncManager.deviceToken, equals('token-for-${syncManager.deviceId}'));
    });

    test('account change invalidates device state and rejects outbox sync', () async {
      await syncManager.registerDevice(fakeClient, userId: 'user-alpha');
      expect(syncManager.isRegistered, isTrue);

      // Attempt sync under a different user account -> must invalidate and throw StateError
      await expectLater(
        () => syncManager.syncPendingEvents(fakeClient, currentUserId: 'user-beta'),
        throwsA(isA<StateError>()),
      );

      // Registration is invalidated
      expect(syncManager.isRegistered, isFalse);
      expect(syncManager.registeredUserId, isNull);
      expect(syncManager.deviceToken, isNull);
    });

    test('syncPendingEvents drains complete backlog across multiple batches', () async {
      await syncManager.registerDevice(fakeClient, userId: 'user-001');

      // Create 5 completed events
      for (var i = 1; i <= 5; i++) {
        final ev = OutboxEvent(
          eventId: 'evt-batch-$i',
          createdAt: DateTime.now(),
          intent: 'set_volume',
          rawTranscript: 'Set volume to ${i * 10}%',
          status: 'success',
        );
        await repository.recordAttempt(ev);
        await repository.recordOutcome(eventId: 'evt-batch-$i', status: 'success');
      }

      // Sync with batchSize: 2 (requires 3 iterations: 2, 2, 1)
      final result = await syncManager.syncPendingEvents(
        fakeClient,
        currentUserId: 'user-001',
        batchSize: 2,
      );

      expect(result.syncedCount, equals(5));
      expect(result.duplicateCount, equals(0));
      expect(result.failedCount, equals(0));
      expect(result.syncedEventIds.length, equals(5));

      // All 5 must now be marked isSynced
      final pendingAfter = await repository.getPendingSyncEvents();
      expect(pendingAfter, isEmpty);
    });

    test('syncPendingEvents omits raw transcript by default (privacy guarantee)', () async {
      await syncManager.registerDevice(fakeClient, userId: 'user-001');

      // Create two completed outbox events in local SQLite
      final event1 = OutboxEvent(
        eventId: 'evt-1',
        createdAt: DateTime.now(),
        intent: 'set_volume',
        rawTranscript: 'Set volume to 40%',
        requestedValue: 40,
        status: 'success',
        actualValue: 40,
      );
      final event2 = OutboxEvent(
        eventId: 'evt-2',
        createdAt: DateTime.now(),
        intent: 'set_volume',
        rawTranscript: 'Set volume to 80%',
        requestedValue: 80,
        status: 'success',
        actualValue: 80,
      );

      await repository.recordAttempt(event1);
      await repository.recordOutcome(eventId: 'evt-1', status: 'success', actualValue: 40);

      await repository.recordAttempt(event2);
      await repository.recordOutcome(eventId: 'evt-2', status: 'success', actualValue: 80);

      // Execute sync
      final result = await syncManager.syncPendingEvents(fakeClient, currentUserId: 'user-001');
      expect(result.syncedCount, equals(2));
      expect(result.duplicateCount, equals(0));

      // Verify privacy boundary in transmitted payload
      final sentBatch = fakeClient.fakeCommandSync.lastBatch;
      expect(sentBatch, isNotNull);
      expect(sentBatch!.entries.length, equals(2));
      expect(sentBatch.entries[0].transcript, isNull);
      expect(sentBatch.entries[1].transcript, isNull);

      // Verify local records are marked isSynced
      final pendingAfter = await repository.getPendingSyncEvents();
      expect(pendingAfter, isEmpty);
    });

    test('syncPendingEvents includes raw transcript when user opts in', () async {
      await syncManager.registerDevice(fakeClient, userId: 'user-001');
      syncManager.isTranscriptSyncEnabled = true;

      final event = OutboxEvent(
        eventId: 'evt-opt-in',
        createdAt: DateTime.now(),
        intent: 'set_volume',
        rawTranscript: 'Set volume to 50%',
        status: 'success',
      );
      await repository.recordAttempt(event);
      await repository.recordOutcome(eventId: 'evt-opt-in', status: 'success');

      final result = await syncManager.syncPendingEvents(fakeClient, currentUserId: 'user-001');
      expect(result.syncedCount, equals(1));

      final sentBatch = fakeClient.fakeCommandSync.lastBatch;
      expect(sentBatch!.entries[0].transcript, equals('Set volume to 50%'));
    });

    test('resending batch succeeds idempotently without duplicate insertions', () async {
      await syncManager.registerDevice(fakeClient, userId: 'user-001');

      final event = OutboxEvent(
        eventId: 'evt-retry',
        createdAt: DateTime.now(),
        intent: 'mute_volume',
        rawTranscript: 'Mute volume',
        status: 'success',
      );
      await repository.recordAttempt(event);
      await repository.recordOutcome(eventId: 'evt-retry', status: 'success');

      // First sync
      final res1 = await syncManager.syncPendingEvents(fakeClient, currentUserId: 'user-001');
      expect(res1.syncedCount, equals(1));
      expect(res1.duplicateCount, equals(0));

      // Simulate network retry: reset local is_synced flag to resend batch
      repository.db.execute("UPDATE outbox_events SET is_synced = 0 WHERE event_id = 'evt-retry'");

      // Second sync (retry)
      final res2 = await syncManager.syncPendingEvents(fakeClient, currentUserId: 'user-001');
      expect(res2.syncedCount, equals(0));
      expect(res2.duplicateCount, equals(1));
      expect(fakeClient.fakeCommandSync.storedEventIds.length, equals(1));
    });
  });
}
