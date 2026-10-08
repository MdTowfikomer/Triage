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
import 'inbox_item.dart' as _iv6iq8qv;

abstract class Recording
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Recording._({
    this.id,
    required this.inboxItemId,
    this.inboxItem,
    required this.storageUrl,
    required this.durationMs,
    required this.createdAt,
  });

  factory Recording({
    int? id,
    required int inboxItemId,
    _iv6iq8qv.InboxItem? inboxItem,
    required String storageUrl,
    required int durationMs,
    required DateTime createdAt,
  }) = _RecordingImpl;

  factory Recording.fromJson(Map<String, dynamic> jsonSerialization) {
    return Recording(
      id: jsonSerialization['id'] as int?,
      inboxItemId: jsonSerialization['inboxItemId'] as int,
      inboxItem: jsonSerialization['inboxItem'] == null
          ? null
          : _ijskpcnf.Protocol().deserialize<_iv6iq8qv.InboxItem>(
              jsonSerialization['inboxItem'],
            ),
      storageUrl: jsonSerialization['storageUrl'] as String,
      durationMs: jsonSerialization['durationMs'] as int,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int inboxItemId;

  _iv6iq8qv.InboxItem? inboxItem;

  String storageUrl;

  int durationMs;

  DateTime createdAt;

  /// Returns a shallow copy of this [Recording]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Recording copyWith({
    int? id,
    int? inboxItemId,
    _iv6iq8qv.InboxItem? inboxItem,
    String? storageUrl,
    int? durationMs,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Recording',
      if (id != null) 'id': id,
      'inboxItemId': inboxItemId,
      if (inboxItem != null) 'inboxItem': inboxItem?.toJson(),
      'storageUrl': storageUrl,
      'durationMs': durationMs,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Recording',
      if (id != null) 'id': id,
      'inboxItemId': inboxItemId,
      if (inboxItem != null) 'inboxItem': inboxItem?.toJsonForProtocol(),
      'storageUrl': storageUrl,
      'durationMs': durationMs,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RecordingImpl extends Recording {
  _RecordingImpl({
    int? id,
    required int inboxItemId,
    _iv6iq8qv.InboxItem? inboxItem,
    required String storageUrl,
    required int durationMs,
    required DateTime createdAt,
  }) : super._(
         id: id,
         inboxItemId: inboxItemId,
         inboxItem: inboxItem,
         storageUrl: storageUrl,
         durationMs: durationMs,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Recording]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Recording copyWith({
    Object? id = _Undefined,
    int? inboxItemId,
    Object? inboxItem = _Undefined,
    String? storageUrl,
    int? durationMs,
    DateTime? createdAt,
  }) {
    return Recording(
      id: id is int? ? id : this.id,
      inboxItemId: inboxItemId ?? this.inboxItemId,
      inboxItem: inboxItem is _iv6iq8qv.InboxItem?
          ? inboxItem
          : this.inboxItem?.copyWith(),
      storageUrl: storageUrl ?? this.storageUrl,
      durationMs: durationMs ?? this.durationMs,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
