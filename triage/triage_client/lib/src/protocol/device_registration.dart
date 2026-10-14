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

abstract class DeviceRegistration
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DeviceRegistration._({
    this.id,
    required this.deviceId,
    required this.userId,
    required this.deviceToken,
    this.deviceName,
    required this.registeredAt,
    this.lastSeenAt,
  });

  factory DeviceRegistration({
    int? id,
    required String deviceId,
    required _isc.UuidValue userId,
    required String deviceToken,
    String? deviceName,
    required DateTime registeredAt,
    DateTime? lastSeenAt,
  }) = _DeviceRegistrationImpl;

  factory DeviceRegistration.fromJson(Map<String, dynamic> jsonSerialization) {
    return DeviceRegistration(
      id: jsonSerialization['id'] as int?,
      deviceId: jsonSerialization['deviceId'] as String,
      userId: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
      deviceToken: jsonSerialization['deviceToken'] as String,
      deviceName: jsonSerialization['deviceName'] as String?,
      registeredAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['registeredAt'],
      ),
      lastSeenAt: jsonSerialization['lastSeenAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastSeenAt'],
            ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String deviceId;

  _isc.UuidValue userId;

  String deviceToken;

  String? deviceName;

  DateTime registeredAt;

  DateTime? lastSeenAt;

  /// Returns a shallow copy of this [DeviceRegistration]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  DeviceRegistration copyWith({
    int? id,
    String? deviceId,
    _isc.UuidValue? userId,
    String? deviceToken,
    String? deviceName,
    DateTime? registeredAt,
    DateTime? lastSeenAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DeviceRegistration',
      if (id != null) 'id': id,
      'deviceId': deviceId,
      'userId': userId.toJson(),
      'deviceToken': deviceToken,
      if (deviceName != null) 'deviceName': deviceName,
      'registeredAt': registeredAt.toJson(),
      if (lastSeenAt != null) 'lastSeenAt': lastSeenAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DeviceRegistration',
      if (id != null) 'id': id,
      'deviceId': deviceId,
      'userId': userId.toJson(),
      'deviceToken': deviceToken,
      if (deviceName != null) 'deviceName': deviceName,
      'registeredAt': registeredAt.toJson(),
      if (lastSeenAt != null) 'lastSeenAt': lastSeenAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DeviceRegistrationImpl extends DeviceRegistration {
  _DeviceRegistrationImpl({
    int? id,
    required String deviceId,
    required _isc.UuidValue userId,
    required String deviceToken,
    String? deviceName,
    required DateTime registeredAt,
    DateTime? lastSeenAt,
  }) : super._(
         id: id,
         deviceId: deviceId,
         userId: userId,
         deviceToken: deviceToken,
         deviceName: deviceName,
         registeredAt: registeredAt,
         lastSeenAt: lastSeenAt,
       );

  /// Returns a shallow copy of this [DeviceRegistration]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DeviceRegistration copyWith({
    Object? id = _Undefined,
    String? deviceId,
    _isc.UuidValue? userId,
    String? deviceToken,
    Object? deviceName = _Undefined,
    DateTime? registeredAt,
    Object? lastSeenAt = _Undefined,
  }) {
    return DeviceRegistration(
      id: id is int? ? id : this.id,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      deviceToken: deviceToken ?? this.deviceToken,
      deviceName: deviceName is String? ? deviceName : this.deviceName,
      registeredAt: registeredAt ?? this.registeredAt,
      lastSeenAt: lastSeenAt is DateTime? ? lastSeenAt : this.lastSeenAt,
    );
  }
}
