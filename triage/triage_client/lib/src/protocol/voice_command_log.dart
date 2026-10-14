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
import 'package:serverpod_client/serverpod_client.dart' as _isc;

abstract class VoiceCommandLog
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  VoiceCommandLog._({
    this.id,
    required this.eventId,
    required this.deviceId,
    required this.intent,
    this.actionTarget,
    required this.resultType,
    this.executionLatencyMs,
    required this.executedOffline,
    required this.syncedAt,
    this.transcript,
  });

  factory VoiceCommandLog({
    int? id,
    required String eventId,
    required String deviceId,
    required String intent,
    String? actionTarget,
    required String resultType,
    int? executionLatencyMs,
    required bool executedOffline,
    required DateTime syncedAt,
    String? transcript,
  }) = _VoiceCommandLogImpl;

  factory VoiceCommandLog.fromJson(Map<String, dynamic> jsonSerialization) {
    return VoiceCommandLog(
      id: jsonSerialization['id'] as int?,
      eventId: jsonSerialization['eventId'] as String,
      deviceId: jsonSerialization['deviceId'] as String,
      intent: jsonSerialization['intent'] as String,
      actionTarget: jsonSerialization['actionTarget'] as String?,
      resultType: jsonSerialization['resultType'] as String,
      executionLatencyMs: jsonSerialization['executionLatencyMs'] as int?,
      executedOffline: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['executedOffline'],
      ),
      syncedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['syncedAt'],
      ),
      transcript: jsonSerialization['transcript'] as String?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String eventId;

  String deviceId;

  String intent;

  String? actionTarget;

  String resultType;

  int? executionLatencyMs;

  bool executedOffline;

  DateTime syncedAt;

  String? transcript;

  /// Returns a shallow copy of this [VoiceCommandLog]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  VoiceCommandLog copyWith({
    int? id,
    String? eventId,
    String? deviceId,
    String? intent,
    String? actionTarget,
    String? resultType,
    int? executionLatencyMs,
    bool? executedOffline,
    DateTime? syncedAt,
    String? transcript,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'VoiceCommandLog',
      if (id != null) 'id': id,
      'eventId': eventId,
      'deviceId': deviceId,
      'intent': intent,
      if (actionTarget != null) 'actionTarget': actionTarget,
      'resultType': resultType,
      if (executionLatencyMs != null) 'executionLatencyMs': executionLatencyMs,
      'executedOffline': executedOffline,
      'syncedAt': syncedAt.toJson(),
      if (transcript != null) 'transcript': transcript,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'VoiceCommandLog',
      if (id != null) 'id': id,
      'eventId': eventId,
      'deviceId': deviceId,
      'intent': intent,
      if (actionTarget != null) 'actionTarget': actionTarget,
      'resultType': resultType,
      if (executionLatencyMs != null) 'executionLatencyMs': executionLatencyMs,
      'executedOffline': executedOffline,
      'syncedAt': syncedAt.toJson(),
      if (transcript != null) 'transcript': transcript,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _VoiceCommandLogImpl extends VoiceCommandLog {
  _VoiceCommandLogImpl({
    int? id,
    required String eventId,
    required String deviceId,
    required String intent,
    String? actionTarget,
    required String resultType,
    int? executionLatencyMs,
    required bool executedOffline,
    required DateTime syncedAt,
    String? transcript,
  }) : super._(
         id: id,
         eventId: eventId,
         deviceId: deviceId,
         intent: intent,
         actionTarget: actionTarget,
         resultType: resultType,
         executionLatencyMs: executionLatencyMs,
         executedOffline: executedOffline,
         syncedAt: syncedAt,
         transcript: transcript,
       );

  /// Returns a shallow copy of this [VoiceCommandLog]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  VoiceCommandLog copyWith({
    Object? id = _Undefined,
    String? eventId,
    String? deviceId,
    String? intent,
    Object? actionTarget = _Undefined,
    String? resultType,
    Object? executionLatencyMs = _Undefined,
    bool? executedOffline,
    DateTime? syncedAt,
    Object? transcript = _Undefined,
  }) {
    return VoiceCommandLog(
      id: id is int? ? id : this.id,
      eventId: eventId ?? this.eventId,
      deviceId: deviceId ?? this.deviceId,
      intent: intent ?? this.intent,
      actionTarget: actionTarget is String? ? actionTarget : this.actionTarget,
      resultType: resultType ?? this.resultType,
      executionLatencyMs: executionLatencyMs is int?
          ? executionLatencyMs
          : this.executionLatencyMs,
      executedOffline: executedOffline ?? this.executedOffline,
      syncedAt: syncedAt ?? this.syncedAt,
      transcript: transcript is String? ? transcript : this.transcript,
    );
  }
}
