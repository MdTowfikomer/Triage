/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _is;

abstract class VoiceCommandSyncEntry
    implements _is.SerializableModel, _is.ProtocolSerialization {
  VoiceCommandSyncEntry._({
    required this.eventId,
    required this.intent,
    this.actionTarget,
    required this.resultType,
    this.executionLatencyMs,
    required this.executedOffline,
    required this.timestamp,
    this.transcript,
  });

  factory VoiceCommandSyncEntry({
    required String eventId,
    required String intent,
    String? actionTarget,
    required String resultType,
    int? executionLatencyMs,
    required bool executedOffline,
    required DateTime timestamp,
    String? transcript,
  }) = _VoiceCommandSyncEntryImpl;

  factory VoiceCommandSyncEntry.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return VoiceCommandSyncEntry(
      eventId: jsonSerialization['eventId'] as String,
      intent: jsonSerialization['intent'] as String,
      actionTarget: jsonSerialization['actionTarget'] as String?,
      resultType: jsonSerialization['resultType'] as String,
      executionLatencyMs: jsonSerialization['executionLatencyMs'] as int?,
      executedOffline: _is.BoolJsonExtension.fromJson(
        jsonSerialization['executedOffline'],
      ),
      timestamp: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['timestamp'],
      ),
      transcript: jsonSerialization['transcript'] as String?,
    );
  }

  String eventId;

  String intent;

  String? actionTarget;

  String resultType;

  int? executionLatencyMs;

  bool executedOffline;

  DateTime timestamp;

  String? transcript;

  /// Returns a shallow copy of this [VoiceCommandSyncEntry]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  VoiceCommandSyncEntry copyWith({
    String? eventId,
    String? intent,
    String? actionTarget,
    String? resultType,
    int? executionLatencyMs,
    bool? executedOffline,
    DateTime? timestamp,
    String? transcript,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'VoiceCommandSyncEntry',
      'eventId': eventId,
      'intent': intent,
      if (actionTarget != null) 'actionTarget': actionTarget,
      'resultType': resultType,
      if (executionLatencyMs != null) 'executionLatencyMs': executionLatencyMs,
      'executedOffline': executedOffline,
      'timestamp': timestamp.toJson(),
      if (transcript != null) 'transcript': transcript,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'VoiceCommandSyncEntry',
      'eventId': eventId,
      'intent': intent,
      if (actionTarget != null) 'actionTarget': actionTarget,
      'resultType': resultType,
      if (executionLatencyMs != null) 'executionLatencyMs': executionLatencyMs,
      'executedOffline': executedOffline,
      'timestamp': timestamp.toJson(),
      if (transcript != null) 'transcript': transcript,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _VoiceCommandSyncEntryImpl extends VoiceCommandSyncEntry {
  _VoiceCommandSyncEntryImpl({
    required String eventId,
    required String intent,
    String? actionTarget,
    required String resultType,
    int? executionLatencyMs,
    required bool executedOffline,
    required DateTime timestamp,
    String? transcript,
  }) : super._(
         eventId: eventId,
         intent: intent,
         actionTarget: actionTarget,
         resultType: resultType,
         executionLatencyMs: executionLatencyMs,
         executedOffline: executedOffline,
         timestamp: timestamp,
         transcript: transcript,
       );

  /// Returns a shallow copy of this [VoiceCommandSyncEntry]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  VoiceCommandSyncEntry copyWith({
    String? eventId,
    String? intent,
    Object? actionTarget = _Undefined,
    String? resultType,
    Object? executionLatencyMs = _Undefined,
    bool? executedOffline,
    DateTime? timestamp,
    Object? transcript = _Undefined,
  }) {
    return VoiceCommandSyncEntry(
      eventId: eventId ?? this.eventId,
      intent: intent ?? this.intent,
      actionTarget: actionTarget is String? ? actionTarget : this.actionTarget,
      resultType: resultType ?? this.resultType,
      executionLatencyMs: executionLatencyMs is int?
          ? executionLatencyMs
          : this.executionLatencyMs,
      executedOffline: executedOffline ?? this.executedOffline,
      timestamp: timestamp ?? this.timestamp,
      transcript: transcript is String? ? transcript : this.transcript,
    );
  }
}
