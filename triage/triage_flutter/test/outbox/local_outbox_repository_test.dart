import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:triage_flutter/outbox/local_outbox_repository.dart';
import 'package:triage_flutter/outbox/outbox_event.dart';
import 'package:triage_flutter/outbox/uuid_util.dart';

void main() {
  late LocalOutboxRepository repository;

  setUp(() async {
    repository = LocalOutboxRepository();
    final inMemoryDb = sqlite3.openInMemory();
    await repository.initialize(customDb: inMemoryDb);
  });

  tearDown(() async {
    await repository.dispose();
  });

  group('LocalOutboxRepository Tests', () {
    test('recordAttempt stores pre-execution event with attempted status', () async {
      final eventId = UuidUtil.generate();
      final event = OutboxEvent(
        eventId: eventId,
        createdAt: DateTime.now(),
        intent: 'set_volume',
        rawTranscript: 'set volume to 50 percent',
        requestedValue: 50,
        status: 'attempted',
        sttLatencyMs: 120,
        parseLatencyMs: 1,
      );

      await repository.recordAttempt(event);

      final retrieved = await repository.getEvent(eventId);
      expect(retrieved, isNotNull);
      expect(retrieved!.eventId, equals(eventId));
      expect(retrieved.status, equals('attempted'));
      expect(retrieved.requestedValue, equals(50));
      expect(retrieved.rawTranscript, equals('set volume to 50 percent'));
      expect(retrieved.completedAt, isNull);
    });

    test('recordOutcome updates status to success with execution metrics', () async {
      final eventId = UuidUtil.generate();
      final event = OutboxEvent(
        eventId: eventId,
        createdAt: DateTime.now(),
        intent: 'set_volume',
        rawTranscript: 'mute volume',
        requestedValue: 0,
        status: 'attempted',
      );

      await repository.recordAttempt(event);

      await repository.recordOutcome(
        eventId: eventId,
        status: 'success',
        previousValue: 50,
        actualValue: 0,
        execLatencyMs: 14,
        ttsLatencyMs: 350,
      );

      final retrieved = await repository.getEvent(eventId);
      expect(retrieved, isNotNull);
      expect(retrieved!.status, equals('success'));
      expect(retrieved.previousValue, equals(50));
      expect(retrieved.actualValue, equals(0));
      expect(retrieved.execLatencyMs, equals(14));
      expect(retrieved.ttsLatencyMs, equals(350));
      expect(retrieved.completedAt, isNotNull);
    });

    test('reconcileBootAttempts converts interrupted attempted records to outcome_unknown without replay', () async {
      final eventIdInterrupted = UuidUtil.generate();
      final eventIdCompleted = UuidUtil.generate();

      // Interrupted attempt: written before execution, but process was terminated
      await repository.recordAttempt(OutboxEvent(
        eventId: eventIdInterrupted,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        intent: 'set_volume',
        rawTranscript: 'set volume to 80',
        requestedValue: 80,
        status: 'attempted',
      ));

      // Successfully completed event
      await repository.recordAttempt(OutboxEvent(
        eventId: eventIdCompleted,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        intent: 'set_volume',
        rawTranscript: 'set volume to 20',
        requestedValue: 20,
        status: 'attempted',
      ));
      await repository.recordOutcome(
        eventId: eventIdCompleted,
        status: 'success',
        previousValue: 50,
        actualValue: 20,
      );

      // Simulate app restart reconciling boot attempts
      final orphaned = await repository.reconcileBootAttempts();

      expect(orphaned.length, equals(1));
      expect(orphaned.first.eventId, equals(eventIdInterrupted));

      // Verify the interrupted record is now outcome_unknown and NOT replayed
      final updatedInterrupted = await repository.getEvent(eventIdInterrupted);
      expect(updatedInterrupted, isNotNull);
      expect(updatedInterrupted!.status, equals('outcome_unknown'));
      expect(updatedInterrupted.errorCode, equals('APP_TERMINATED_PRE_OUTCOME'));
      expect(updatedInterrupted.errorMessage, contains('Replay suppressed'));

      // Verify completed event remained untouched
      final completedEvent = await repository.getEvent(eventIdCompleted);
      expect(completedEvent!.status, equals('success'));
    });
  });
}
