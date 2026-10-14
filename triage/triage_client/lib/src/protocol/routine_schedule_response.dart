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

abstract class RoutineScheduleResponse
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  RoutineScheduleResponse._({
    required this.routineId,
    required this.status,
    required this.scheduledTime,
  });

  factory RoutineScheduleResponse({
    required String routineId,
    required String status,
    required DateTime scheduledTime,
  }) = _RoutineScheduleResponseImpl;

  factory RoutineScheduleResponse.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return RoutineScheduleResponse(
      routineId: jsonSerialization['routineId'] as String,
      status: jsonSerialization['status'] as String,
      scheduledTime: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['scheduledTime'],
      ),
    );
  }

  String routineId;

  String status;

  DateTime scheduledTime;

  /// Returns a shallow copy of this [RoutineScheduleResponse]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  RoutineScheduleResponse copyWith({
    String? routineId,
    String? status,
    DateTime? scheduledTime,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RoutineScheduleResponse',
      'routineId': routineId,
      'status': status,
      'scheduledTime': scheduledTime.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'RoutineScheduleResponse',
      'routineId': routineId,
      'status': status,
      'scheduledTime': scheduledTime.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _RoutineScheduleResponseImpl extends RoutineScheduleResponse {
  _RoutineScheduleResponseImpl({
    required String routineId,
    required String status,
    required DateTime scheduledTime,
  }) : super._(
         routineId: routineId,
         status: status,
         scheduledTime: scheduledTime,
       );

  /// Returns a shallow copy of this [RoutineScheduleResponse]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  RoutineScheduleResponse copyWith({
    String? routineId,
    String? status,
    DateTime? scheduledTime,
  }) {
    return RoutineScheduleResponse(
      routineId: routineId ?? this.routineId,
      status: status ?? this.status,
      scheduledTime: scheduledTime ?? this.scheduledTime,
    );
  }
}
