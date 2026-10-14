import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:triage_client/triage_client.dart';
import 'package:triage_flutter/actions/action_result.dart';
import 'package:triage_flutter/actions/native_action_client.dart';
import 'package:triage_flutter/outbox/local_outbox_repository.dart';
import 'package:triage_flutter/routines/routine_execution_manager.dart';

class _FakeEndpointRoutine extends Fake implements EndpointRoutine {
  RoutineAcknowledgementEvent? lastAck;

  @override
  Future<bool> acknowledgeRoutine(RoutineAcknowledgementEvent ack) async {
    lastAck = ack;
    return true;
  }
}

class _FakeClient extends Fake implements Client {
  final fakeRoutine = _FakeEndpointRoutine();

  @override
  EndpointRoutine get routine => fakeRoutine;
}

class _FakeNativeActionClient extends Fake implements NativeActionClient {
  bool succeed = true;
  dynamic targetSet;
  String? failError;

  @override
  Future<ActionResult> setVolume(dynamic percent, {bool showUi = true}) async {
    targetSet = percent;
    if (succeed) {
      return ActionResult(
        status: ActionStatus.success,
        action: 'set_volume',
        targetValue: percent,
        previousValue: 50,
        executionLatencyMs: 10,
      );
    } else {
      return ActionResult(
        status: ActionStatus.error,
        action: 'set_volume',
        errorMessage: failError ?? 'Hardware volume failure',
        executionLatencyMs: 10,
      );
    }
  }
}

void main() {
  late LocalOutboxRepository repository;
  late _FakeNativeActionClient actionClient;
  late _FakeClient client;
  late RoutineExecutionManager manager;

  setUp(() async {
    repository = LocalOutboxRepository();
    final inMemoryDb = sqlite3.openInMemory();
    await repository.initialize(customDb: inMemoryDb);

    actionClient = _FakeNativeActionClient();
    client = _FakeClient();
    manager = RoutineExecutionManager(
      repository: repository,
      actionClient: actionClient,
    );
  });

  tearDown(() async {
    manager.dispose();
    await repository.dispose();
  });

  group('RoutineExecutionManager Tests', () {
    test('reports expired when dispatch is received past expiresAt', () async {
      final past = DateTime.now().toUtc().subtract(const Duration(minutes: 10));
      final event = RoutineDispatchEvent(
        routineOccurrenceId: 'occ-expired-001',
        routineId: 'rout-001',
        deviceId: 'dev-001',
        name: 'Mute',
        stepsJson: '[{"stepId":"s1","action":"set_volume","targetValue":0}]',
        scheduledTime: past.subtract(const Duration(minutes: 5)),
        expiresAt: past,
        dispatchedAt: past,
      );

      final report = await manager.handleDispatchEvent(
        client,
        event: event,
        deviceId: 'dev-001',
        deviceToken: 'token-001',
      );

      expect(report.status, equals('expired'));
      expect(client.fakeRoutine.lastAck?.status, equals('expired'));
      expect(actionClient.targetSet, isNull);
    });

    test('suppresses execution when occurrence is already claimed in local SQLite', () async {
      final now = DateTime.now().toUtc();
      final event = RoutineDispatchEvent(
        routineOccurrenceId: 'occ-claimed-001',
        routineId: 'rout-002',
        deviceId: 'dev-001',
        name: 'Mute',
        stepsJson: '[{"stepId":"s1","action":"set_volume","targetValue":0}]',
        scheduledTime: now,
        expiresAt: now.add(const Duration(minutes: 5)),
        dispatchedAt: now,
      );

      // Pre-claim occurrence in repository
      final firstClaim = await repository.attemptClaimRoutineOccurrence(
        'occ-claimed-001',
        'rout-002',
      );
      expect(firstClaim, isTrue);

      final report = await manager.handleDispatchEvent(
        client,
        event: event,
        deviceId: 'dev-001',
        deviceToken: 'token-001',
      );

      expect(report.status, equals('already_claimed'));
      expect(client.fakeRoutine.lastAck?.status, equals('already_claimed'));
      expect(actionClient.targetSet, isNull);
    });

    test('rejects empty steps list and reports partial_failure with client note', () async {
      final now = DateTime.now().toUtc();
      final event = RoutineDispatchEvent(
        routineOccurrenceId: 'occ-empty-001',
        routineId: 'rout-empty-001',
        deviceId: 'dev-001',
        name: 'Empty Steps Routine',
        stepsJson: '[]',
        scheduledTime: now,
        expiresAt: now.add(const Duration(minutes: 5)),
        dispatchedAt: now,
      );

      final report = await manager.handleDispatchEvent(
        client,
        event: event,
        deviceId: 'dev-001',
        deviceToken: 'token-001',
      );

      expect(report.status, equals('partial_failure'));
      expect(client.fakeRoutine.lastAck?.status, equals('partial_failure'));
      expect(client.fakeRoutine.lastAck?.clientNote, contains('Routine contains no executable steps'));
      expect(actionClient.targetSet, isNull);
    });

    test('rejects malformed stepsJson and reports partial_failure with client note', () async {
      final now = DateTime.now().toUtc();
      final event = RoutineDispatchEvent(
        routineOccurrenceId: 'occ-malformed-001',
        routineId: 'rout-malformed-001',
        deviceId: 'dev-001',
        name: 'Malformed Steps Routine',
        stepsJson: '{invalid-json}',
        scheduledTime: now,
        expiresAt: now.add(const Duration(minutes: 5)),
        dispatchedAt: now,
      );

      final report = await manager.handleDispatchEvent(
        client,
        event: event,
        deviceId: 'dev-001',
        deviceToken: 'token-001',
      );

      expect(report.status, equals('partial_failure'));
      expect(client.fakeRoutine.lastAck?.status, equals('partial_failure'));
      expect(client.fakeRoutine.lastAck?.clientNote, contains('Failed to parse stepsJson'));
      expect(actionClient.targetSet, isNull);
    });

    test('rejects non-object elements in stepsJson and reports partial_failure', () async {
      final now = DateTime.now().toUtc();
      final event = RoutineDispatchEvent(
        routineOccurrenceId: 'occ-non-map-001',
        routineId: 'rout-non-map-001',
        deviceId: 'dev-001',
        name: 'Non-map Step Routine',
        stepsJson: '[123, "string-step"]',
        scheduledTime: now,
        expiresAt: now.add(const Duration(minutes: 5)),
        dispatchedAt: now,
      );

      final report = await manager.handleDispatchEvent(
        client,
        event: event,
        deviceId: 'dev-001',
        deviceToken: 'token-001',
      );

      expect(report.status, equals('partial_failure'));
      expect(client.fakeRoutine.lastAck?.status, equals('partial_failure'));
      expect(client.fakeRoutine.lastAck?.clientNote, contains('Malformed step descriptor'));
      expect(actionClient.targetSet, isNull);
    });

    test('executes valid volume step successfully and reports completed', () async {
      final now = DateTime.now().toUtc();
      final event = RoutineDispatchEvent(
        routineOccurrenceId: 'occ-success-001',
        routineId: 'rout-success-001',
        deviceId: 'dev-001',
        name: 'Valid Mute Routine',
        stepsJson: '[{"stepId":"s1","action":"set_volume","targetValue":0}]',
        scheduledTime: now,
        expiresAt: now.add(const Duration(minutes: 5)),
        dispatchedAt: now,
      );

      final report = await manager.handleDispatchEvent(
        client,
        event: event,
        deviceId: 'dev-001',
        deviceToken: 'token-001',
      );

      expect(report.status, equals('completed'));
      expect(actionClient.targetSet, equals(0));
      expect(client.fakeRoutine.lastAck?.status, equals('completed'));
      expect(client.fakeRoutine.lastAck?.stepOutcomes.first.status, equals('success'));
      expect(client.fakeRoutine.lastAck?.clientNote, isNull);
    });

    test('reports partial_failure when native volume bridge fails', () async {
      actionClient.succeed = false;
      actionClient.failError = 'Native volume stream muted by system';

      final now = DateTime.now().toUtc();
      final event = RoutineDispatchEvent(
        routineOccurrenceId: 'occ-fail-001',
        routineId: 'rout-fail-001',
        deviceId: 'dev-001',
        name: 'Failing Routine',
        stepsJson: '[{"stepId":"s1","action":"set_volume","targetValue":0}]',
        scheduledTime: now,
        expiresAt: now.add(const Duration(minutes: 5)),
        dispatchedAt: now,
      );

      final report = await manager.handleDispatchEvent(
        client,
        event: event,
        deviceId: 'dev-001',
        deviceToken: 'token-001',
      );

      expect(report.status, equals('partial_failure'));
      expect(client.fakeRoutine.lastAck?.status, equals('partial_failure'));
      expect(client.fakeRoutine.lastAck?.clientNote, contains('Native volume stream muted'));
    });
  });
}
