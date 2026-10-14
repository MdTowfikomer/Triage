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

abstract class VoiceCommandSyncResult
    implements _is.SerializableModel, _is.ProtocolSerialization {
  VoiceCommandSyncResult._({
    required this.syncedCount,
    required this.duplicateCount,
    required this.failedCount,
    required this.syncedEventIds,
  });

  factory VoiceCommandSyncResult({
    required int syncedCount,
    required int duplicateCount,
    required int failedCount,
    required List<String> syncedEventIds,
  }) = _VoiceCommandSyncResultImpl;

  factory VoiceCommandSyncResult.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return VoiceCommandSyncResult(
      syncedCount: jsonSerialization['syncedCount'] as int,
      duplicateCount: jsonSerialization['duplicateCount'] as int,
      failedCount: jsonSerialization['failedCount'] as int,
      syncedEventIds: _ishkju68.Protocol().deserialize<List<String>>(
        jsonSerialization['syncedEventIds'],
      ),
    );
  }

  int syncedCount;

  int duplicateCount;

  int failedCount;

  List<String> syncedEventIds;

  /// Returns a shallow copy of this [VoiceCommandSyncResult]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  VoiceCommandSyncResult copyWith({
    int? syncedCount,
    int? duplicateCount,
    int? failedCount,
    List<String>? syncedEventIds,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'VoiceCommandSyncResult',
      'syncedCount': syncedCount,
      'duplicateCount': duplicateCount,
      'failedCount': failedCount,
      'syncedEventIds': syncedEventIds.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'VoiceCommandSyncResult',
      'syncedCount': syncedCount,
      'duplicateCount': duplicateCount,
      'failedCount': failedCount,
      'syncedEventIds': syncedEventIds.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _VoiceCommandSyncResultImpl extends VoiceCommandSyncResult {
  _VoiceCommandSyncResultImpl({
    required int syncedCount,
    required int duplicateCount,
    required int failedCount,
    required List<String> syncedEventIds,
  }) : super._(
         syncedCount: syncedCount,
         duplicateCount: duplicateCount,
         failedCount: failedCount,
         syncedEventIds: syncedEventIds,
       );

  /// Returns a shallow copy of this [VoiceCommandSyncResult]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  VoiceCommandSyncResult copyWith({
    int? syncedCount,
    int? duplicateCount,
    int? failedCount,
    List<String>? syncedEventIds,
  }) {
    return VoiceCommandSyncResult(
      syncedCount: syncedCount ?? this.syncedCount,
      duplicateCount: duplicateCount ?? this.duplicateCount,
      failedCount: failedCount ?? this.failedCount,
      syncedEventIds:
          syncedEventIds ?? this.syncedEventIds.map((e0) => e0).toList(),
    );
  }
}
