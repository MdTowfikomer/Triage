import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:triage_client/triage_client.dart';
import 'package:triage_flutter/actions/action_result.dart';
import 'package:triage_flutter/actions/native_action_client.dart';
import 'package:triage_flutter/outbox/local_outbox_repository.dart';
import 'package:triage_flutter/routines/routine_execution_manager.dart';

class MockNativeActionClient extends Fake implements NativeActionClient {
  int? lastSetVolume;
  bool shouldFail = false;

  @override
  Future<ActionResult> setVolume(dynamic percent, {bool showUi = true}) async {
    if (shouldFail) {
      return const ActionResult(
        status: ActionStatus.error,
        action: 'set_volume',
        errorCode: 'PERMISSION_DENIED',
        errorMessage: 'Mock hardware error',
        executionLatencyMs: 8,
      );
    }
    lastSetVolume = percent is int ? percent : (percent as num).toInt();
    return ActionResult(
      status: ActionStatus.success,
      action: 'set_volume',
      targetValue: lastSetVolume,
      previousValue: 50,
      executionLatencyMs: 8,
    );
  }

  @override
  Future<ActionResult> getVolume() async {
    return ActionResult(
      status: ActionStatus.success,
      action: 'get_volume',
      targetValue: lastSetVolume ?? 50,
      executionLatencyMs: 5,
    );
  }
}

class MockEndpointRoutine extends Fake implements EndpointRoutine {
  RoutineAcknowledgementEvent? lastAck;

  @override
  Future<bool> acknowledgeRoutine(RoutineAcknowledgementEvent ack) async {
    lastAck = ack;
    return true;
  }
}

class MockClient extends Fake implements Client {
  final mockRoutine = MockEndpointRoutine();

  @override
  EndpointRoutine get routine => mockRoutine;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalOutboxRepository repo;
  late MockNativeActionClient mockActionClient;
  late RoutineExecutionManager manager;
  late MockClient mockClient;

  setUp(() async {
    repo = LocalOutboxRepository();
    await repo.initialize(customDb: sqlite3.openInMemory());
    mockActionClient = MockNativeActionClient();
    manager = RoutineExecutionManager(
      repository: repo,
      actionClient: mockActionClient,
    );
    mockClient = MockClient();
  });

  tearDown(() async {
    await repo.dispose();
  });

  test('attemptClaimRoutineOccurrence atomically succeeds once and rejects duplicate', () async {
    const occId = 'occ-test-001';
    const routineId = 'routine-test-001';

    final first = await repo.attemptClaimRoutineOccurrence(occId, routineId);
    expect(first, isTrue);

    final second = await repo.attemptClaimRoutineOccurrence(occId, routineId);
    expect(second, isFalse); // Suppressed by SQLite UNIQUE constraint!

    final isClaimed = await repo.isRoutineOccurrenceClaimed(occId);
    expect(isClaimed, isTrue);
  });

  test('handleDispatchEvent aborts and acknowledges expired if past expiresAt', () async {
    final event = RoutineDispatchEvent(
      routineOccurrenceId: 'occ-exp-001',
      routineId: 'routine-exp-001',
      deviceId: 'device-001',
      name: 'Late Routine',
      stepsJson: '[{"action":"set_volume","targetValue":0}]',
      scheduledTime: DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
      expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      dispatchedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
    );

    final report = await manager.handleDispatchEvent(
      mockClient,
      event: event,
      deviceId: 'device-001',
      deviceToken: 'token-001',
    );

    expect(report.status, equals('expired'));
    expect(mockActionClient.lastSetVolume, isNull); // Native executor was NOT run!
    expect(mockClient.mockRoutine.lastAck?.status, equals('expired'));
  });

  test('handleDispatchEvent aborts duplicate execution if occurrence is already claimed', () async {
    const occId = 'occ-dup-001';
    await repo.attemptClaimRoutineOccurrence(occId, 'routine-dup-001');

    final event = RoutineDispatchEvent(
      routineOccurrenceId: occId,
      routineId: 'routine-dup-001',
      deviceId: 'device-001',
      name: 'Duplicate Routine',
      stepsJson: '[{"action":"set_volume","targetValue":0}]',
      scheduledTime: DateTime.now().toUtc(),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      dispatchedAt: DateTime.now().toUtc(),
    );

    final report = await manager.handleDispatchEvent(
      mockClient,
      event: event,
      deviceId: 'device-001',
      deviceToken: 'token-001',
    );

    expect(report.status, equals('already_claimed'));
    expect(mockActionClient.lastSetVolume, isNull); // Volume NOT touched!
    expect(mockClient.mockRoutine.lastAck?.status, equals('already_claimed'));
  });

  test('handleDispatchEvent executes set_volume unattended and acknowledges completed', () async {
    final event = RoutineDispatchEvent(
      routineOccurrenceId: 'occ-success-001',
      routineId: 'routine-success-001',
      deviceId: 'device-001',
      name: 'Meeting Prep: Set volume to 0%',
      stepsJson: '[{"stepId":"s1","action":"set_volume","targetValue":0,"unattended":true}]',
      scheduledTime: DateTime.now().toUtc(),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      dispatchedAt: DateTime.now().toUtc(),
    );

    final report = await manager.handleDispatchEvent(
      mockClient,
      event: event,
      deviceId: 'device-001',
      deviceToken: 'token-001',
    );

    expect(report.status, equals('completed'));
    expect(mockActionClient.lastSetVolume, equals(0)); // Volume muted to 0%!
    expect(mockClient.mockRoutine.lastAck?.status, equals('completed'));
    expect(mockClient.mockRoutine.lastAck?.stepOutcomes.first.status, equals('success'));
    expect(mockClient.mockRoutine.lastAck?.stepOutcomes.first.actualValue, equals('0'));
  });

  test('handleDispatchEvent acknowledges partial_failure when a step fails', () async {
    mockActionClient.shouldFail = true;

    final event = RoutineDispatchEvent(
      routineOccurrenceId: 'occ-fail-001',
      routineId: 'routine-fail-001',
      deviceId: 'device-001',
      name: 'Failing Routine',
      stepsJson: '[{"stepId":"s1","action":"set_volume","targetValue":0}]',
      scheduledTime: DateTime.now().toUtc(),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      dispatchedAt: DateTime.now().toUtc(),
    );

    final report = await manager.handleDispatchEvent(
      mockClient,
      event: event,
      deviceId: 'device-001',
      deviceToken: 'token-001',
    );

    expect(report.status, equals('partial_failure'));
    expect(mockClient.mockRoutine.lastAck?.status, equals('partial_failure'));
    expect(mockClient.mockRoutine.lastAck?.stepOutcomes.first.status, equals('failed'));
    expect(mockClient.mockRoutine.lastAck?.stepOutcomes.first.errorMessage, contains('Mock hardware error'));
  });
}
