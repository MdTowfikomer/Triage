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
import 'package:triage_server/src/generated/protocol.dart' as _ishkju68;
import 'voice_command_sync_entry.dart' as _is11prk2;

abstract class VoiceCommandSyncBatch
    implements _is.SerializableModel, _is.ProtocolSerialization {
  VoiceCommandSyncBatch._({
    required this.deviceId,
    required this.deviceToken,
    required this.entries,
  });

  factory VoiceCommandSyncBatch({
    required String deviceId,
    required String deviceToken,
    required List<_is11prk2.VoiceCommandSyncEntry> entries,
  }) = _VoiceCommandSyncBatchImpl;

  factory VoiceCommandSyncBatch.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return VoiceCommandSyncBatch(
      deviceId: jsonSerialization['deviceId'] as String,
      deviceToken: jsonSerialization['deviceToken'] as String,
      entries: _ishkju68.Protocol()
          .deserialize<List<_is11prk2.VoiceCommandSyncEntry>>(
            jsonSerialization['entries'],
          ),
    );
  }

  String deviceId;

  String deviceToken;

  List<_is11prk2.VoiceCommandSyncEntry> entries;

  /// Returns a shallow copy of this [VoiceCommandSyncBatch]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  VoiceCommandSyncBatch copyWith({
    String? deviceId,
    String? deviceToken,
    List<_is11prk2.VoiceCommandSyncEntry>? entries,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'VoiceCommandSyncBatch',
      'deviceId': deviceId,
      'deviceToken': deviceToken,
      'entries': entries.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'VoiceCommandSyncBatch',
      'deviceId': deviceId,
      'deviceToken': deviceToken,
      'entries': entries.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _VoiceCommandSyncBatchImpl extends VoiceCommandSyncBatch {
  _VoiceCommandSyncBatchImpl({
    required String deviceId,
    required String deviceToken,
    required List<_is11prk2.VoiceCommandSyncEntry> entries,
  }) : super._(
         deviceId: deviceId,
         deviceToken: deviceToken,
         entries: entries,
       );

  /// Returns a shallow copy of this [VoiceCommandSyncBatch]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  VoiceCommandSyncBatch copyWith({
    String? deviceId,
    String? deviceToken,
    List<_is11prk2.VoiceCommandSyncEntry>? entries,
  }) {
    return VoiceCommandSyncBatch(
      deviceId: deviceId ?? this.deviceId,
      deviceToken: deviceToken ?? this.deviceToken,
      entries: entries ?? this.entries.map((e0) => e0.copyWith()).toList(),
    );
  }
}
