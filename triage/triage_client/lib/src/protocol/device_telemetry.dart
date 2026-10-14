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

abstract class DeviceTelemetry
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DeviceTelemetry._({
    this.id,
    required this.deviceId,
    required this.batteryLevel,
    required this.isCharging,
    required this.volumeLevel,
    required this.brightnessLevel,
    required this.dndEnabled,
    required this.updatedAt,
  });

  factory DeviceTelemetry({
    int? id,
    required String deviceId,
    required int batteryLevel,
    required bool isCharging,
    required double volumeLevel,
    required double brightnessLevel,
    required bool dndEnabled,
    required DateTime updatedAt,
  }) = _DeviceTelemetryImpl;

  factory DeviceTelemetry.fromJson(Map<String, dynamic> jsonSerialization) {
    return DeviceTelemetry(
      id: jsonSerialization['id'] as int?,
      deviceId: jsonSerialization['deviceId'] as String,
      batteryLevel: jsonSerialization['batteryLevel'] as int,
      isCharging: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['isCharging'],
      ),
      volumeLevel: (jsonSerialization['volumeLevel'] as num).toDouble(),
      brightnessLevel: (jsonSerialization['brightnessLevel'] as num).toDouble(),
      dndEnabled: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['dndEnabled'],
      ),
      updatedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String deviceId;

  int batteryLevel;

  bool isCharging;

  double volumeLevel;

  double brightnessLevel;

  bool dndEnabled;

  DateTime updatedAt;

  /// Returns a shallow copy of this [DeviceTelemetry]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  DeviceTelemetry copyWith({
    int? id,
    String? deviceId,
    int? batteryLevel,
    bool? isCharging,
    double? volumeLevel,
    double? brightnessLevel,
    bool? dndEnabled,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DeviceTelemetry',
      if (id != null) 'id': id,
      'deviceId': deviceId,
      'batteryLevel': batteryLevel,
      'isCharging': isCharging,
      'volumeLevel': volumeLevel,
      'brightnessLevel': brightnessLevel,
      'dndEnabled': dndEnabled,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DeviceTelemetry',
      if (id != null) 'id': id,
      'deviceId': deviceId,
      'batteryLevel': batteryLevel,
      'isCharging': isCharging,
      'volumeLevel': volumeLevel,
      'brightnessLevel': brightnessLevel,
      'dndEnabled': dndEnabled,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DeviceTelemetryImpl extends DeviceTelemetry {
  _DeviceTelemetryImpl({
    int? id,
    required String deviceId,
    required int batteryLevel,
    required bool isCharging,
    required double volumeLevel,
    required double brightnessLevel,
    required bool dndEnabled,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         deviceId: deviceId,
         batteryLevel: batteryLevel,
         isCharging: isCharging,
         volumeLevel: volumeLevel,
         brightnessLevel: brightnessLevel,
         dndEnabled: dndEnabled,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [DeviceTelemetry]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DeviceTelemetry copyWith({
    Object? id = _Undefined,
    String? deviceId,
    int? batteryLevel,
    bool? isCharging,
    double? volumeLevel,
    double? brightnessLevel,
    bool? dndEnabled,
    DateTime? updatedAt,
  }) {
    return DeviceTelemetry(
      id: id is int? ? id : this.id,
      deviceId: deviceId ?? this.deviceId,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      volumeLevel: volumeLevel ?? this.volumeLevel,
      brightnessLevel: brightnessLevel ?? this.brightnessLevel,
      dndEnabled: dndEnabled ?? this.dndEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
