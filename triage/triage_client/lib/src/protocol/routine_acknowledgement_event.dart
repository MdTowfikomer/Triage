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
import 'package:triage_client/src/protocol/protocol.dart' as _ijskpcnf;
import 'routine_step_outcome.dart' as _iztwdzxw;

abstract class RoutineAcknowledgementEvent
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  RoutineAcknowledgementEvent._({
    required this.routineOccurrenceId,
    required this.routineId,
    required this.deviceId,
    required this.deviceToken,
    required this.status,
    required this.stepOutcomes,
    required this.completedAt,
    this.clientNote,
  });

  factory RoutineAcknowledgementEvent({
    required String routineOccurrenceId,
    required String routineId,
    required String deviceId,
    required String deviceToken,
    required String status,
    required List<_iztwdzxw.RoutineStepOutcome> stepOutcomes,
    required DateTime completedAt,
    String? clientNote,
  }) = _RoutineAcknowledgementEventImpl;

  factory RoutineAcknowledgementEvent.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return RoutineAcknowledgementEvent(
      routineOccurrenceId: jsonSerialization['routineOccurrenceId'] as String,
      routineId: jsonSerialization['routineId'] as String,
      deviceId: jsonSerialization['deviceId'] as String,
      deviceToken: jsonSerialization['deviceToken'] as String,
      status: jsonSerialization['status'] as String,
      stepOutcomes: _ijskpcnf.Protocol()
          .deserialize<List<_iztwdzxw.RoutineStepOutcome>>(
            jsonSerialization['stepOutcomes'],
          ),
      completedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['completedAt'],
      ),
      clientNote: jsonSerialization['clientNote'] as String?,
    );
  }

  String routineOccurrenceId;

  String routineId;

  String deviceId;

  String deviceToken;

  String status;

  List<_iztwdzxw.RoutineStepOutcome> stepOutcomes;

  DateTime completedAt;

  String? clientNote;

  /// Returns a shallow copy of this [RoutineAcknowledgementEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  RoutineAcknowledgementEvent copyWith({
    String? routineOccurrenceId,
    String? routineId,
    String? deviceId,
    String? deviceToken,
    String? status,
    List<_iztwdzxw.RoutineStepOutcome>? stepOutcomes,
    DateTime? completedAt,
    String? clientNote,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RoutineAcknowledgementEvent',
      'routineOccurrenceId': routineOccurrenceId,
      'routineId': routineId,
      'deviceId': deviceId,
      'deviceToken': deviceToken,
      'status': status,
      'stepOutcomes': stepOutcomes.toJson(valueToJson: (v) => v.toJson()),
      'completedAt': completedAt.toJson(),
      if (clientNote != null) 'clientNote': clientNote,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'RoutineAcknowledgementEvent',
      'routineOccurrenceId': routineOccurrenceId,
      'routineId': routineId,
      'deviceId': deviceId,
      'deviceToken': deviceToken,
      'status': status,
      'stepOutcomes': stepOutcomes.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
      'completedAt': completedAt.toJson(),
      if (clientNote != null) 'clientNote': clientNote,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RoutineAcknowledgementEventImpl extends RoutineAcknowledgementEvent {
  _RoutineAcknowledgementEventImpl({
    required String routineOccurrenceId,
    required String routineId,
    required String deviceId,
    required String deviceToken,
    required String status,
    required List<_iztwdzxw.RoutineStepOutcome> stepOutcomes,
    required DateTime completedAt,
    String? clientNote,
  }) : super._(
         routineOccurrenceId: routineOccurrenceId,
         routineId: routineId,
         deviceId: deviceId,
         deviceToken: deviceToken,
         status: status,
         stepOutcomes: stepOutcomes,
         completedAt: completedAt,
         clientNote: clientNote,
       );

  /// Returns a shallow copy of this [RoutineAcknowledgementEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  RoutineAcknowledgementEvent copyWith({
    String? routineOccurrenceId,
    String? routineId,
    String? deviceId,
    String? deviceToken,
    String? status,
    List<_iztwdzxw.RoutineStepOutcome>? stepOutcomes,
    DateTime? completedAt,
    Object? clientNote = _Undefined,
  }) {
    return RoutineAcknowledgementEvent(
      routineOccurrenceId: routineOccurrenceId ?? this.routineOccurrenceId,
      routineId: routineId ?? this.routineId,
      deviceId: deviceId ?? this.deviceId,
      deviceToken: deviceToken ?? this.deviceToken,
      status: status ?? this.status,
      stepOutcomes:
          stepOutcomes ?? this.stepOutcomes.map((e0) => e0.copyWith()).toList(),
      completedAt: completedAt ?? this.completedAt,
      clientNote: clientNote is String? ? clientNote : this.clientNote,
    );
  }
}
