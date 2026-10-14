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

abstract class DeviceRegistrationResponse
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DeviceRegistrationResponse._({
    required this.deviceId,
    required this.deviceToken,
    required this.registeredAt,
  });

  factory DeviceRegistrationResponse({
    required String deviceId,
    required String deviceToken,
    required DateTime registeredAt,
  }) = _DeviceRegistrationResponseImpl;

  factory DeviceRegistrationResponse.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return DeviceRegistrationResponse(
      deviceId: jsonSerialization['deviceId'] as String,
      deviceToken: jsonSerialization['deviceToken'] as String,
      registeredAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['registeredAt'],
      ),
    );
  }

  String deviceId;

  String deviceToken;

  DateTime registeredAt;

  /// Returns a shallow copy of this [DeviceRegistrationResponse]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  DeviceRegistrationResponse copyWith({
    String? deviceId,
    String? deviceToken,
    DateTime? registeredAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DeviceRegistrationResponse',
      'deviceId': deviceId,
      'deviceToken': deviceToken,
      'registeredAt': registeredAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DeviceRegistrationResponse',
      'deviceId': deviceId,
      'deviceToken': deviceToken,
      'registeredAt': registeredAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _DeviceRegistrationResponseImpl extends DeviceRegistrationResponse {
  _DeviceRegistrationResponseImpl({
    required String deviceId,
    required String deviceToken,
    required DateTime registeredAt,
  }) : super._(
         deviceId: deviceId,
         deviceToken: deviceToken,
         registeredAt: registeredAt,
       );

  /// Returns a shallow copy of this [DeviceRegistrationResponse]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DeviceRegistrationResponse copyWith({
    String? deviceId,
    String? deviceToken,
    DateTime? registeredAt,
  }) {
    return DeviceRegistrationResponse(
      deviceId: deviceId ?? this.deviceId,
      deviceToken: deviceToken ?? this.deviceToken,
      registeredAt: registeredAt ?? this.registeredAt,
    );
  }
}
