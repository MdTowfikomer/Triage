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

abstract class RoutineSchedule
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  RoutineSchedule._({
    this.id,
    required this.routineId,
    required this.deviceId,
    required this.userId,
    required this.name,
    required this.scheduledTime,
    required this.stepsJson,
    required this.status,
    required this.createdAt,
    this.dispatchedAt,
    this.completedAt,
    this.lastError,
    this.lastOccurrenceId,
  });

  factory RoutineSchedule({
    int? id,
    required String routineId,
    required String deviceId,
    required _isc.UuidValue userId,
    required String name,
    required DateTime scheduledTime,
    required String stepsJson,
    required String status,
    required DateTime createdAt,
    DateTime? dispatchedAt,
    DateTime? completedAt,
    String? lastError,
    String? lastOccurrenceId,
  }) = _RoutineScheduleImpl;

  factory RoutineSchedule.fromJson(Map<String, dynamic> jsonSerialization) {
    return RoutineSchedule(
      id: jsonSerialization['id'] as int?,
      routineId: jsonSerialization['routineId'] as String,
      deviceId: jsonSerialization['deviceId'] as String,
      userId: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
      name: jsonSerialization['name'] as String,
      scheduledTime: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['scheduledTime'],
      ),
      stepsJson: jsonSerialization['stepsJson'] as String,
      status: jsonSerialization['status'] as String,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      dispatchedAt: jsonSerialization['dispatchedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['dispatchedAt'],
            ),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      lastError: jsonSerialization['lastError'] as String?,
      lastOccurrenceId: jsonSerialization['lastOccurrenceId'] as String?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String routineId;

  String deviceId;

  _isc.UuidValue userId;

  String name;

  DateTime scheduledTime;

  String stepsJson;

  String status;

  DateTime createdAt;

  DateTime? dispatchedAt;

  DateTime? completedAt;

  String? lastError;

  String? lastOccurrenceId;

  /// Returns a shallow copy of this [RoutineSchedule]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  RoutineSchedule copyWith({
    int? id,
    String? routineId,
    String? deviceId,
    _isc.UuidValue? userId,
    String? name,
    DateTime? scheduledTime,
    String? stepsJson,
    String? status,
    DateTime? createdAt,
    DateTime? dispatchedAt,
    DateTime? completedAt,
    String? lastError,
    String? lastOccurrenceId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RoutineSchedule',
      if (id != null) 'id': id,
      'routineId': routineId,
      'deviceId': deviceId,
      'userId': userId.toJson(),
      'name': name,
      'scheduledTime': scheduledTime.toJson(),
      'stepsJson': stepsJson,
      'status': status,
      'createdAt': createdAt.toJson(),
      if (dispatchedAt != null) 'dispatchedAt': dispatchedAt?.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      if (lastError != null) 'lastError': lastError,
      if (lastOccurrenceId != null) 'lastOccurrenceId': lastOccurrenceId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'RoutineSchedule',
      if (id != null) 'id': id,
      'routineId': routineId,
      'deviceId': deviceId,
      'userId': userId.toJson(),
      'name': name,
      'scheduledTime': scheduledTime.toJson(),
      'stepsJson': stepsJson,
      'status': status,
      'createdAt': createdAt.toJson(),
      if (dispatchedAt != null) 'dispatchedAt': dispatchedAt?.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      if (lastError != null) 'lastError': lastError,
      if (lastOccurrenceId != null) 'lastOccurrenceId': lastOccurrenceId,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RoutineScheduleImpl extends RoutineSchedule {
  _RoutineScheduleImpl({
    int? id,
    required String routineId,
    required String deviceId,
    required _isc.UuidValue userId,
    required String name,
    required DateTime scheduledTime,
    required String stepsJson,
    required String status,
    required DateTime createdAt,
    DateTime? dispatchedAt,
    DateTime? completedAt,
    String? lastError,
    String? lastOccurrenceId,
  }) : super._(
         id: id,
         routineId: routineId,
         deviceId: deviceId,
         userId: userId,
         name: name,
         scheduledTime: scheduledTime,
         stepsJson: stepsJson,
         status: status,
         createdAt: createdAt,
         dispatchedAt: dispatchedAt,
         completedAt: completedAt,
         lastError: lastError,
         lastOccurrenceId: lastOccurrenceId,
       );

  /// Returns a shallow copy of this [RoutineSchedule]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  RoutineSchedule copyWith({
    Object? id = _Undefined,
    String? routineId,
    String? deviceId,
    _isc.UuidValue? userId,
    String? name,
    DateTime? scheduledTime,
    String? stepsJson,
    String? status,
    DateTime? createdAt,
    Object? dispatchedAt = _Undefined,
    Object? completedAt = _Undefined,
    Object? lastError = _Undefined,
    Object? lastOccurrenceId = _Undefined,
  }) {
    return RoutineSchedule(
      id: id is int? ? id : this.id,
      routineId: routineId ?? this.routineId,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      stepsJson: stepsJson ?? this.stepsJson,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dispatchedAt: dispatchedAt is DateTime?
          ? dispatchedAt
          : this.dispatchedAt,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
      lastError: lastError is String? ? lastError : this.lastError,
      lastOccurrenceId: lastOccurrenceId is String?
          ? lastOccurrenceId
          : this.lastOccurrenceId,
    );
  }
}
