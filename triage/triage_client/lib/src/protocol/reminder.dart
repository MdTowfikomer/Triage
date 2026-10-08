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

abstract class Reminder
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Reminder._({
    this.id,
    required this.inboxItemId,
    this.inboxItem,
    required this.triggerAt,
    required this.recurring,
    bool? isFired,
    required this.createdAt,
  }) : isFired = isFired ?? false;

  factory Reminder({
    int? id,
    required int inboxItemId,
    _iv6iq8qv.InboxItem? inboxItem,
    required DateTime triggerAt,
    required String recurring,
    bool? isFired,
    required DateTime createdAt,
  }) = _ReminderImpl;

  factory Reminder.fromJson(Map<String, dynamic> jsonSerialization) {
    return Reminder(
      id: jsonSerialization['id'] as int?,
      inboxItemId: jsonSerialization['inboxItemId'] as int,
      inboxItem: jsonSerialization['inboxItem'] == null
          ? null
          : _ijskpcnf.Protocol().deserialize<_iv6iq8qv.InboxItem>(
              jsonSerialization['inboxItem'],
            ),
      triggerAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['triggerAt'],
      ),
      recurring: jsonSerialization['recurring'] as String,
      isFired: jsonSerialization['isFired'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['isFired']),
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

  DateTime triggerAt;

  String recurring;

  bool isFired;

  DateTime createdAt;

  /// Returns a shallow copy of this [Reminder]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Reminder copyWith({
    int? id,
    int? inboxItemId,
    _iv6iq8qv.InboxItem? inboxItem,
    DateTime? triggerAt,
    String? recurring,
    bool? isFired,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Reminder',
      if (id != null) 'id': id,
      'inboxItemId': inboxItemId,
      if (inboxItem != null) 'inboxItem': inboxItem?.toJson(),
      'triggerAt': triggerAt.toJson(),
      'recurring': recurring,
      'isFired': isFired,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Reminder',
      if (id != null) 'id': id,
      'inboxItemId': inboxItemId,
      if (inboxItem != null) 'inboxItem': inboxItem?.toJsonForProtocol(),
      'triggerAt': triggerAt.toJson(),
      'recurring': recurring,
      'isFired': isFired,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ReminderImpl extends Reminder {
  _ReminderImpl({
    int? id,
    required int inboxItemId,
    _iv6iq8qv.InboxItem? inboxItem,
    required DateTime triggerAt,
    required String recurring,
    bool? isFired,
    required DateTime createdAt,
  }) : super._(
         id: id,
         inboxItemId: inboxItemId,
         inboxItem: inboxItem,
         triggerAt: triggerAt,
         recurring: recurring,
         isFired: isFired,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Reminder]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Reminder copyWith({
    Object? id = _Undefined,
    int? inboxItemId,
    Object? inboxItem = _Undefined,
    DateTime? triggerAt,
    String? recurring,
    bool? isFired,
    DateTime? createdAt,
  }) {
    return Reminder(
      id: id is int? ? id : this.id,
      inboxItemId: inboxItemId ?? this.inboxItemId,
      inboxItem: inboxItem is _iv6iq8qv.InboxItem?
          ? inboxItem
          : this.inboxItem?.copyWith(),
      triggerAt: triggerAt ?? this.triggerAt,
      recurring: recurring ?? this.recurring,
      isFired: isFired ?? this.isFired,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
