import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'outbox_event.dart';

/// Durable local SQLite storage for assistant outbox and audit events.
/// Enforces the pre-execution audit write pattern and prevents blind replay on crash.
class LocalOutboxRepository {
  Database? _db;

  Database get db {
    if (_db == null) {
      throw StateError('LocalOutboxRepository is not initialized. Call initialize() first.');
    }
    return _db!;
  }

  bool get isOpen => _db != null;

  /// Initializes the SQLite database. Supports in-memory database or custom path for testing.
  Future<void> initialize({Database? customDb, String? dbPath}) async {
    if (_db != null) return;

    if (customDb != null) {
      _db = customDb;
    } else {
      final path = dbPath ?? await _getDefaultDatabasePath();
      final file = File(path);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      _db = sqlite3.open(path);
      _db!.execute('PRAGMA journal_mode = WAL;');
      _db!.execute('PRAGMA synchronous = NORMAL;');
    }

    _createSchema();
  }

  static Future<String> _getDefaultDatabasePath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return p.join(docsDir.path, 'triage_outbox.db');
  }

  void _createSchema() {
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS outbox_events (
        event_id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        intent TEXT NOT NULL,
        raw_transcript TEXT NOT NULL,
        requested_value INTEGER,
        status TEXT NOT NULL,
        previous_value INTEGER,
        actual_value INTEGER,
        error_code TEXT,
        error_message TEXT,
        stt_latency_ms INTEGER,
        parse_latency_ms INTEGER,
        exec_latency_ms INTEGER,
        tts_latency_ms INTEGER,
        completed_at TEXT,
        is_synced INTEGER DEFAULT 0
      );
    ''');
    try {
      _db!.execute('ALTER TABLE outbox_events ADD COLUMN is_synced INTEGER DEFAULT 0;');
    } catch (_) {
      // Column already exists in upgraded database
    }
    _db!.execute('CREATE INDEX IF NOT EXISTS idx_outbox_status ON outbox_events(status);');
    _db!.execute('CREATE INDEX IF NOT EXISTS idx_outbox_created_at ON outbox_events(created_at);');
    _db!.execute('CREATE INDEX IF NOT EXISTS idx_outbox_synced ON outbox_events(is_synced);');

    // Ticket 05: Atomic Local Routine Execution Claims
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS routine_claims (
        occurrence_id TEXT PRIMARY KEY,
        routine_id TEXT NOT NULL,
        claimed_at TEXT NOT NULL,
        status TEXT NOT NULL,
        outcomes_json TEXT
      );
    ''');
    _db!.execute('CREATE INDEX IF NOT EXISTS idx_routine_claims_routine_id ON routine_claims(routine_id);');

    // Ticket 10: Local Routine Mirroring & Doze Reconciliation
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS local_routines (
        routine_id TEXT PRIMARY KEY,
        occurrence_id TEXT NOT NULL,
        name TEXT NOT NULL,
        scheduled_time TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        steps_json TEXT NOT NULL,
        status TEXT NOT NULL
      );
    ''');
    _db!.execute('CREATE INDEX IF NOT EXISTS idx_local_routines_sched ON local_routines(scheduled_time);');
  }

  /// CRITICAL STEP 1: Durable Pre-Execution Write.
  /// Persists the intent and requested parameters before native side-effects occur.
  Future<void> recordAttempt(OutboxEvent event) async {
    if (!isOpen) {
      await initialize();
    }
    final stmt = db.prepare('''
      INSERT INTO outbox_events (
        event_id, created_at, intent, raw_transcript, requested_value,
        status, previous_value, actual_value, error_code, error_message,
        stt_latency_ms, parse_latency_ms, exec_latency_ms, tts_latency_ms, completed_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');

    try {
      stmt.execute([
        event.eventId,
        event.createdAt.toUtc().toIso8601String(),
        event.intent,
        event.rawTranscript,
        event.requestedValue,
        'attempted', // Always enforce 'attempted' status on pre-execution
        event.previousValue,
        event.actualValue,
        event.errorCode,
        event.errorMessage,
        event.sttLatencyMs,
        event.parseLatencyMs,
        event.execLatencyMs,
        event.ttsLatencyMs,
        event.completedAt?.toUtc().toIso8601String(),
      ]);
    } finally {
      stmt.close();
    }
  }

  /// CRITICAL STEP 2: Post-Execution Outcome Update.
  /// Records success or failure alongside native execution latency and actual hardware state.
  Future<void> recordOutcome({
    required String eventId,
    required String status,
    int? previousValue,
    int? actualValue,
    String? errorCode,
    String? errorMessage,
    int? execLatencyMs,
    int? ttsLatencyMs,
  }) async {
    if (!isOpen) {
      await initialize();
    }
    final completedAt = DateTime.now().toUtc().toIso8601String();
    final stmt = db.prepare('''
      UPDATE outbox_events SET
        status = ?,
        previous_value = ?,
        actual_value = ?,
        error_code = ?,
        error_message = ?,
        exec_latency_ms = ?,
        tts_latency_ms = ?,
        completed_at = ?
      WHERE event_id = ?
    ''');

    try {
      stmt.execute([
        status,
        previousValue,
        actualValue,
        errorCode,
        errorMessage,
        execLatencyMs,
        ttsLatencyMs,
        completedAt,
        eventId,
      ]);
    } finally {
      stmt.close();
    }
  }

  /// CRITICAL STEP 3: Crash Recovery & Reconciliation.
  /// If the app or system process terminated between pre-execution write and outcome update,
  /// any lingering 'attempted' record is marked 'outcome_unknown'.
  /// IT IS NEVER REPLAYED AUTOMATICALLY to avoid dangerous uncommanded side-effects.
  Future<List<OutboxEvent>> reconcileBootAttempts() async {
    if (!isOpen) {
      await initialize();
    }
    final selectStmt = db.prepare("SELECT * FROM outbox_events WHERE status = 'attempted'");
    final List<OutboxEvent> orphaned = [];
    try {
      final rows = selectStmt.select();
      for (final row in rows) {
        orphaned.add(OutboxEvent.fromMap(row));
      }
    } finally {
      selectStmt.close();
    }

    if (orphaned.isNotEmpty) {
      final updateStmt = db.prepare('''
        UPDATE outbox_events SET
          status = 'outcome_unknown',
          error_code = 'APP_TERMINATED_PRE_OUTCOME',
          error_message = 'Process terminated before outcome could be verified. Replay suppressed.',
          completed_at = ?
        WHERE status = 'attempted'
      ''');
      try {
        updateStmt.execute([DateTime.now().toUtc().toIso8601String()]);
      } finally {
        updateStmt.close();
      }
    }

    return orphaned;
  }

  /// Retrieves recent outbox audit records ordered from newest to oldest.
  Future<List<OutboxEvent>> getRecentEvents({int limit = 50}) async {
    if (!isOpen) {
      await initialize();
    }
    final stmt = db.prepare('SELECT * FROM outbox_events ORDER BY created_at DESC LIMIT ?');
    try {
      final rows = stmt.select([limit]);
      return rows.map((r) => OutboxEvent.fromMap(r)).toList();
    } finally {
      stmt.close();
    }
  }

  /// Retrieves a specific outbox event by UUID.
  Future<OutboxEvent?> getEvent(String eventId) async {
    final stmt = db.prepare('SELECT * FROM outbox_events WHERE event_id = ?');
    try {
      final rows = stmt.select([eventId]);
      if (rows.isEmpty) return null;
      return OutboxEvent.fromMap(rows.first);
    } finally {
      stmt.close();
    }
  }

  /// Retrieves events eligible for synchronization (completed outcomes with is_synced = 0).
  Future<List<OutboxEvent>> getPendingSyncEvents({int limit = 100}) async {
    if (!isOpen) {
      await initialize();
    }
    final stmt = db.prepare(
      "SELECT * FROM outbox_events WHERE status != 'attempted' AND is_synced = 0 ORDER BY created_at ASC LIMIT ?",
    );
    try {
      final rows = stmt.select([limit]);
      return rows.map((r) => OutboxEvent.fromMap(r)).toList();
    } finally {
      stmt.close();
    }
  }

  /// Returns the total count of events pending synchronization.
  Future<int> getPendingSyncCount() async {
    if (!isOpen) {
      await initialize();
    }
    final rows = db.select("SELECT COUNT(*) AS cnt FROM outbox_events WHERE status != 'attempted' AND is_synced = 0");
    if (rows.isEmpty) return 0;
    return (rows.first['cnt'] as num?)?.toInt() ?? 0;
  }

  /// Marks a collection of event IDs as synced in the local SQLite database.
  Future<void> markEventsSynced(List<String> eventIds) async {
    if (!isOpen) {
      await initialize();
    }
    if (eventIds.isEmpty) return;

    db.execute('BEGIN TRANSACTION');
    final stmt = db.prepare('UPDATE outbox_events SET is_synced = 1 WHERE event_id = ?');
    try {
      for (final id in eventIds) {
        stmt.execute([id]);
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    } finally {
      stmt.close();
    }
  }

  /// Attempts to atomically claim a routine occurrence in local SQLite storage.
  /// Returns true if claim succeeded; false if occurrence was already claimed (duplicate suppression).
  Future<bool> attemptClaimRoutineOccurrence(String occurrenceId, String routineId) async {
    if (!isOpen) {
      await initialize();
    }
    final stmt = db.prepare('''
      INSERT INTO routine_claims (occurrence_id, routine_id, claimed_at, status)
      VALUES (?, ?, ?, 'claimed')
    ''');
    try {
      stmt.execute([
        occurrenceId,
        routineId,
        DateTime.now().toUtc().toIso8601String(),
      ]);
      return true;
    } on SqliteException catch (e) {
      if (e.message.contains('UNIQUE constraint failed') || e.resultCode == 19) {
        return false;
      }
      rethrow;
    } finally {
      stmt.close();
    }
  }

  /// Updates local routine claim record with execution status and outcome details.
  Future<void> updateRoutineOccurrenceOutcome(
    String occurrenceId, {
    required String status,
    String? outcomesJson,
  }) async {
    if (!isOpen) {
      await initialize();
    }
    final stmt = db.prepare('''
      UPDATE routine_claims
      SET status = ?, outcomes_json = ?
      WHERE occurrence_id = ?
    ''');
    try {
      stmt.execute([status, outcomesJson, occurrenceId]);
    } finally {
      stmt.close();
    }
  }

  /// Checks if occurrence is already claimed.
  Future<bool> isRoutineOccurrenceClaimed(String occurrenceId) async {
    if (!isOpen) {
      await initialize();
    }
    final res = db.select(
      'SELECT 1 FROM routine_claims WHERE occurrence_id = ?',
      [occurrenceId],
    );
    return res.isNotEmpty;
  }

  /// Saves or updates a local mirrored routine schedule.
  Future<void> saveLocalRoutine(LocalRoutineRecord record) async {
    if (!isOpen) {
      await initialize();
    }
    final stmt = db.prepare('''
      INSERT INTO local_routines (routine_id, occurrence_id, name, scheduled_time, expires_at, steps_json, status)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(routine_id) DO UPDATE SET
        occurrence_id = excluded.occurrence_id,
        name = excluded.name,
        scheduled_time = excluded.scheduled_time,
        expires_at = excluded.expires_at,
        steps_json = excluded.steps_json,
        status = excluded.status
    ''');
    try {
      stmt.execute([
        record.routineId,
        record.occurrenceId,
        record.name,
        record.scheduledTime.toUtc().toIso8601String(),
        record.expiresAt.toUtc().toIso8601String(),
        record.stepsJson,
        record.status,
      ]);
    } finally {
      stmt.close();
    }
  }

  /// Retrieves all local mirrored routines.
  Future<List<LocalRoutineRecord>> getLocalRoutines() async {
    if (!isOpen) {
      await initialize();
    }
    final stmt = db.prepare('SELECT * FROM local_routines ORDER BY scheduled_time ASC');
    try {
      final rows = stmt.select([]);
      return rows.map((r) => LocalRoutineRecord.fromMap(r)).toList();
    } finally {
      stmt.close();
    }
  }

  /// Retrieves a specific mirrored routine by ID.
  Future<LocalRoutineRecord?> getLocalRoutine(String routineId) async {
    if (!isOpen) {
      await initialize();
    }
    final stmt = db.prepare('SELECT * FROM local_routines WHERE routine_id = ?');
    try {
      final rows = stmt.select([routineId]);
      if (rows.isEmpty) return null;
      return LocalRoutineRecord.fromMap(rows.first);
    } finally {
      stmt.close();
    }
  }

  /// Retrieves a specific mirrored routine by occurrence ID.
  Future<LocalRoutineRecord?> getLocalRoutineByOccurrenceId(String occurrenceId) async {
    if (!isOpen) {
      await initialize();
    }
    final stmt = db.prepare('SELECT * FROM local_routines WHERE occurrence_id = ?');
    try {
      final rows = stmt.select([occurrenceId]);
      if (rows.isEmpty) return null;
      return LocalRoutineRecord.fromMap(rows.first);
    } finally {
      stmt.close();
    }
  }

  /// Updates status of a mirrored local routine.
  Future<void> updateLocalRoutineStatus(String routineId, String status) async {
    if (!isOpen) {
      await initialize();
    }
    final stmt = db.prepare('UPDATE local_routines SET status = ? WHERE routine_id = ?');
    try {
      stmt.execute([status, routineId]);
    } finally {
      stmt.close();
    }
  }

  /// Closes database connection.
  Future<void> dispose() async {
    _db?.close();
    _db = null;
  }
}

class LocalRoutineRecord {
  final String routineId;
  final String occurrenceId;
  final String name;
  final DateTime scheduledTime;
  final DateTime expiresAt;
  final String stepsJson;
  final String status;

  const LocalRoutineRecord({
    required this.routineId,
    required this.occurrenceId,
    required this.name,
    required this.scheduledTime,
    required this.expiresAt,
    required this.stepsJson,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'routine_id': routineId,
        'occurrence_id': occurrenceId,
        'name': name,
        'scheduled_time': scheduledTime.toUtc().toIso8601String(),
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'steps_json': stepsJson,
        'status': status,
      };

  factory LocalRoutineRecord.fromMap(Map<String, dynamic> map) => LocalRoutineRecord(
        routineId: map['routine_id'] as String,
        occurrenceId: map['occurrence_id'] as String,
        name: map['name'] as String,
        scheduledTime: DateTime.parse(map['scheduled_time'] as String),
        expiresAt: DateTime.parse(map['expires_at'] as String),
        stepsJson: map['steps_json'] as String,
        status: map['status'] as String,
      );
}
