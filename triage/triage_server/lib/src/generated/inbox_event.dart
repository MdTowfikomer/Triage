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
import 'inbox_item.dart' as _iv6iq8qv;

abstract class InboxEvent
    implements _is.SerializableModel, _is.ProtocolSerialization {
  InboxEvent._({
    required this.operation,
    required this.itemId,
    this.item,
    required this.occurredAt,
  });

  factory InboxEvent({
    required String operation,
    required int itemId,
    _iv6iq8qv.InboxItem? item,
    required DateTime occurredAt,
  }) = _InboxEventImpl;

  factory InboxEvent.fromJson(Map<String, dynamic> jsonSerialization) {
    return InboxEvent(
      operation: jsonSerialization['operation'] as String,
      itemId: jsonSerialization['itemId'] as int,
      item: jsonSerialization['item'] == null
          ? null
          : _ishkju68.Protocol().deserialize<_iv6iq8qv.InboxItem>(
              jsonSerialization['item'],
            ),
      occurredAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['occurredAt'],
      ),
    );
  }

  String operation;

  int itemId;

  _iv6iq8qv.InboxItem? item;

  DateTime occurredAt;

  /// Returns a shallow copy of this [InboxEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  InboxEvent copyWith({
    String? operation,
    int? itemId,
    _iv6iq8qv.InboxItem? item,
    DateTime? occurredAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'InboxEvent',
      'operation': operation,
      'itemId': itemId,
      if (item != null) 'item': item?.toJson(),
      'occurredAt': occurredAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'InboxEvent',
      'operation': operation,
      'itemId': itemId,
      if (item != null) 'item': item?.toJsonForProtocol(),
      'occurredAt': occurredAt.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _InboxEventImpl extends InboxEvent {
  _InboxEventImpl({
    required String operation,
    required int itemId,
    _iv6iq8qv.InboxItem? item,
    required DateTime occurredAt,
  }) : super._(
         operation: operation,
         itemId: itemId,
         item: item,
         occurredAt: occurredAt,
       );

  /// Returns a shallow copy of this [InboxEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  InboxEvent copyWith({
    String? operation,
    int? itemId,
    Object? item = _Undefined,
    DateTime? occurredAt,
  }) {
    return InboxEvent(
      operation: operation ?? this.operation,
      itemId: itemId ?? this.itemId,
      item: item is _iv6iq8qv.InboxItem? ? item : this.item?.copyWith(),
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }
}
