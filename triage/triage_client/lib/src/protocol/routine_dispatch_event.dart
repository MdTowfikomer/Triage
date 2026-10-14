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

abstract class RoutineDispatchEvent
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  RoutineDispatchEvent._({
    required this.routineOccurrenceId,
    required this.routineId,
    required this.deviceId,
    required this.name,
    required this.stepsJson,
    required this.scheduledTime,
    required this.expiresAt,
    required this.dispatchedAt,
  });

  factory RoutineDispatchEvent({
    required String routineOccurrenceId,
    required String routineId,
    required String deviceId,
    required String name,
    required String stepsJson,
    required DateTime scheduledTime,
    required DateTime expiresAt,
    required DateTime dispatchedAt,
  }) = _RoutineDispatchEventImpl;

  factory RoutineDispatchEvent.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return RoutineDispatchEvent(
      routineOccurrenceId: jsonSerialization['routineOccurrenceId'] as String,
      routineId: jsonSerialization['routineId'] as String,
      deviceId: jsonSerialization['deviceId'] as String,
      name: jsonSerialization['name'] as String,
      stepsJson: jsonSerialization['stepsJson'] as String,
      scheduledTime: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['scheduledTime'],
      ),
      expiresAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
      dispatchedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['dispatchedAt'],
      ),
    );
  }

  String routineOccurrenceId;

  String routineId;

  String deviceId;

  String name;

  String stepsJson;

  DateTime scheduledTime;

  DateTime expiresAt;

  DateTime dispatchedAt;

  /// Returns a shallow copy of this [RoutineDispatchEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  RoutineDispatchEvent copyWith({
    String? routineOccurrenceId,
    String? routineId,
    String? deviceId,
    String? name,
    String? stepsJson,
    DateTime? scheduledTime,
    DateTime? expiresAt,
    DateTime? dispatchedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RoutineDispatchEvent',
      'routineOccurrenceId': routineOccurrenceId,
      'routineId': routineId,
      'deviceId': deviceId,
      'name': name,
      'stepsJson': stepsJson,
      'scheduledTime': scheduledTime.toJson(),
      'expiresAt': expiresAt.toJson(),
      'dispatchedAt': dispatchedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'RoutineDispatchEvent',
      'routineOccurrenceId': routineOccurrenceId,
      'routineId': routineId,
      'deviceId': deviceId,
      'name': name,
      'stepsJson': stepsJson,
      'scheduledTime': scheduledTime.toJson(),
      'expiresAt': expiresAt.toJson(),
      'dispatchedAt': dispatchedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _RoutineDispatchEventImpl extends RoutineDispatchEvent {
  _RoutineDispatchEventImpl({
    required String routineOccurrenceId,
    required String routineId,
    required String deviceId,
    required String name,
    required String stepsJson,
    required DateTime scheduledTime,
    required DateTime expiresAt,
    required DateTime dispatchedAt,
  }) : super._(
         routineOccurrenceId: routineOccurrenceId,
         routineId: routineId,
         deviceId: deviceId,
         name: name,
         stepsJson: stepsJson,
         scheduledTime: scheduledTime,
         expiresAt: expiresAt,
         dispatchedAt: dispatchedAt,
       );

  /// Returns a shallow copy of this [RoutineDispatchEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  RoutineDispatchEvent copyWith({
    String? routineOccurrenceId,
    String? routineId,
    String? deviceId,
    String? name,
    String? stepsJson,
    DateTime? scheduledTime,
    DateTime? expiresAt,
    DateTime? dispatchedAt,
  }) {
    return RoutineDispatchEvent(
      routineOccurrenceId: routineOccurrenceId ?? this.routineOccurrenceId,
      routineId: routineId ?? this.routineId,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      stepsJson: stepsJson ?? this.stepsJson,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      expiresAt: expiresAt ?? this.expiresAt,
      dispatchedAt: dispatchedAt ?? this.dispatchedAt,
    );
  }
}
