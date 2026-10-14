/// Represents an audit entry in the local durable SQLite outbox.
class OutboxEvent {
  final String eventId;
  final DateTime createdAt;
  final String intent;
  final String rawTranscript;
  final int? requestedValue;
  final String status; // 'attempted', 'success', 'error', 'outcome_unknown'
  final int? previousValue;
  final int? actualValue;
  final String? errorCode;
  final String? errorMessage;
  final int? sttLatencyMs;
  final int? parseLatencyMs;
  final int? execLatencyMs;
  final int? ttsLatencyMs;
  final DateTime? completedAt;
  final bool isSynced;

  const OutboxEvent({
    required this.eventId,
    required this.createdAt,
    required this.intent,
    required this.rawTranscript,
    this.requestedValue,
    required this.status,
    this.previousValue,
    this.actualValue,
    this.errorCode,
    this.errorMessage,
    this.sttLatencyMs,
    this.parseLatencyMs,
    this.execLatencyMs,
    this.ttsLatencyMs,
    this.completedAt,
    this.isSynced = false,
  });

  bool get isAttempted => status == 'attempted';
  bool get isSuccess => status == 'success';
  bool get isError => status == 'error';
  bool get isOutcomeUnknown => status == 'outcome_unknown';

  OutboxEvent copyWith({
    String? status,
    int? previousValue,
    int? actualValue,
    String? errorCode,
    String? errorMessage,
    int? sttLatencyMs,
    int? parseLatencyMs,
    int? execLatencyMs,
    int? ttsLatencyMs,
    DateTime? completedAt,
    bool? isSynced,
  }) {
    return OutboxEvent(
      eventId: eventId,
      createdAt: createdAt,
      intent: intent,
      rawTranscript: rawTranscript,
      requestedValue: requestedValue,
      status: status ?? this.status,
      previousValue: previousValue ?? this.previousValue,
      actualValue: actualValue ?? this.actualValue,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      sttLatencyMs: sttLatencyMs ?? this.sttLatencyMs,
      parseLatencyMs: parseLatencyMs ?? this.parseLatencyMs,
      execLatencyMs: execLatencyMs ?? this.execLatencyMs,
      ttsLatencyMs: ttsLatencyMs ?? this.ttsLatencyMs,
      completedAt: completedAt ?? this.completedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'intent': intent,
      'raw_transcript': rawTranscript,
      'requested_value': requestedValue,
      'status': status,
      'previous_value': previousValue,
      'actual_value': actualValue,
      'error_code': errorCode,
      'error_message': errorMessage,
      'stt_latency_ms': sttLatencyMs,
      'parse_latency_ms': parseLatencyMs,
      'exec_latency_ms': execLatencyMs,
      'tts_latency_ms': ttsLatencyMs,
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory OutboxEvent.fromMap(Map<String, dynamic> map) {
    return OutboxEvent(
      eventId: map['event_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      intent: map['intent'] as String,
      rawTranscript: (map['raw_transcript'] as String?) ?? '',
      requestedValue: (map['requested_value'] as num?)?.toInt(),
      status: map['status'] as String,
      previousValue: (map['previous_value'] as num?)?.toInt(),
      actualValue: (map['actual_value'] as num?)?.toInt(),
      errorCode: map['error_code'] as String?,
      errorMessage: map['error_message'] as String?,
      sttLatencyMs: (map['stt_latency_ms'] as num?)?.toInt(),
      parseLatencyMs: (map['parse_latency_ms'] as num?)?.toInt(),
      execLatencyMs: (map['exec_latency_ms'] as num?)?.toInt(),
      ttsLatencyMs: (map['tts_latency_ms'] as num?)?.toInt(),
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at'] as String) : null,
      isSynced: (map['is_synced'] as int?) == 1,
    );
  }
}
