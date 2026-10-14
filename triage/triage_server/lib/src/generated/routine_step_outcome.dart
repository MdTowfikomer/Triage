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

abstract class RoutineStepOutcome
    implements _is.SerializableModel, _is.ProtocolSerialization {
  RoutineStepOutcome._({
    required this.stepId,
    required this.action,
    required this.status,
    required this.latencyMs,
    this.errorMessage,
    this.actualValue,
  });

  factory RoutineStepOutcome({
    required String stepId,
    required String action,
    required String status,
    required int latencyMs,
    String? errorMessage,
    String? actualValue,
  }) = _RoutineStepOutcomeImpl;

  factory RoutineStepOutcome.fromJson(Map<String, dynamic> jsonSerialization) {
    return RoutineStepOutcome(
      stepId: jsonSerialization['stepId'] as String,
      action: jsonSerialization['action'] as String,
      status: jsonSerialization['status'] as String,
      latencyMs: jsonSerialization['latencyMs'] as int,
      errorMessage: jsonSerialization['errorMessage'] as String?,
      actualValue: jsonSerialization['actualValue'] as String?,
    );
  }

  String stepId;

  String action;

  String status;

  int latencyMs;

  String? errorMessage;

  String? actualValue;

  /// Returns a shallow copy of this [RoutineStepOutcome]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  RoutineStepOutcome copyWith({
    String? stepId,
    String? action,
    String? status,
    int? latencyMs,
    String? errorMessage,
    String? actualValue,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RoutineStepOutcome',
      'stepId': stepId,
      'action': action,
      'status': status,
      'latencyMs': latencyMs,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (actualValue != null) 'actualValue': actualValue,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'RoutineStepOutcome',
      'stepId': stepId,
      'action': action,
      'status': status,
      'latencyMs': latencyMs,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (actualValue != null) 'actualValue': actualValue,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RoutineStepOutcomeImpl extends RoutineStepOutcome {
  _RoutineStepOutcomeImpl({
    required String stepId,
    required String action,
    required String status,
    required int latencyMs,
    String? errorMessage,
    String? actualValue,
  }) : super._(
         stepId: stepId,
         action: action,
         status: status,
         latencyMs: latencyMs,
         errorMessage: errorMessage,
         actualValue: actualValue,
       );

  /// Returns a shallow copy of this [RoutineStepOutcome]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  RoutineStepOutcome copyWith({
    String? stepId,
    String? action,
    String? status,
    int? latencyMs,
    Object? errorMessage = _Undefined,
    Object? actualValue = _Undefined,
  }) {
    return RoutineStepOutcome(
      stepId: stepId ?? this.stepId,
      action: action ?? this.action,
      status: status ?? this.status,
      latencyMs: latencyMs ?? this.latencyMs,
      errorMessage: errorMessage is String? ? errorMessage : this.errorMessage,
      actualValue: actualValue is String? ? actualValue : this.actualValue,
    );
  }
}
