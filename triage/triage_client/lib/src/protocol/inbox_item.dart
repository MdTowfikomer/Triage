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
import 'recording.dart' as _ih2awd28;
import 'reminder.dart' as _ic7cmrsw;

abstract class InboxItem
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  InboxItem._({
    this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.body,
    this.tags,
    this.priority,
    this.emoji,
    this.dueDate,
    required this.redactedTranscript,
    bool? isCompleted,
    this.completedAt,
    this.confidence,
    required this.createdAt,
    this.reminder,
    this.recording,
  }) : isCompleted = isCompleted ?? false;

  factory InboxItem({
    int? id,
    required _isc.UuidValue userId,
    required String type,
    required String title,
    String? body,
    List<String>? tags,
    String? priority,
    String? emoji,
    DateTime? dueDate,
    required String redactedTranscript,
    bool? isCompleted,
    DateTime? completedAt,
    double? confidence,
    required DateTime createdAt,
    _ic7cmrsw.Reminder? reminder,
    _ih2awd28.Recording? recording,
  }) = _InboxItemImpl;

  factory InboxItem.fromJson(Map<String, dynamic> jsonSerialization) {
    return InboxItem(
      id: jsonSerialization['id'] as int?,
      userId: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
      type: jsonSerialization['type'] as String,
      title: jsonSerialization['title'] as String,
      body: jsonSerialization['body'] as String?,
      tags: jsonSerialization['tags'] == null
          ? null
          : _ijskpcnf.Protocol().deserialize<List<String>>(
              jsonSerialization['tags'],
            ),
      priority: jsonSerialization['priority'] as String?,
      emoji: jsonSerialization['emoji'] as String?,
      dueDate: jsonSerialization['dueDate'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['dueDate']),
      redactedTranscript: jsonSerialization['redactedTranscript'] as String,
      isCompleted: jsonSerialization['isCompleted'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['isCompleted']),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      confidence: (jsonSerialization['confidence'] as num?)?.toDouble(),
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      reminder: jsonSerialization['reminder'] == null
          ? null
          : _ijskpcnf.Protocol().deserialize<_ic7cmrsw.Reminder>(
              jsonSerialization['reminder'],
            ),
      recording: jsonSerialization['recording'] == null
          ? null
          : _ijskpcnf.Protocol().deserialize<_ih2awd28.Recording>(
              jsonSerialization['recording'],
            ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  _isc.UuidValue userId;

  String type;

  String title;

  String? body;

  List<String>? tags;

  String? priority;

  String? emoji;

  DateTime? dueDate;

  String redactedTranscript;

  bool isCompleted;

  DateTime? completedAt;

  double? confidence;

  DateTime createdAt;

  _ic7cmrsw.Reminder? reminder;

  _ih2awd28.Recording? recording;

  /// Returns a shallow copy of this [InboxItem]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  InboxItem copyWith({
    int? id,
    _isc.UuidValue? userId,
    String? type,
    String? title,
    String? body,
    List<String>? tags,
    String? priority,
    String? emoji,
    DateTime? dueDate,
    String? redactedTranscript,
    bool? isCompleted,
    DateTime? completedAt,
    double? confidence,
    DateTime? createdAt,
    _ic7cmrsw.Reminder? reminder,
    _ih2awd28.Recording? recording,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'InboxItem',
      if (id != null) 'id': id,
      'userId': userId.toJson(),
      'type': type,
      'title': title,
      if (body != null) 'body': body,
      if (tags != null) 'tags': tags?.toJson(),
      if (priority != null) 'priority': priority,
      if (emoji != null) 'emoji': emoji,
      if (dueDate != null) 'dueDate': dueDate?.toJson(),
      'redactedTranscript': redactedTranscript,
      'isCompleted': isCompleted,
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      if (confidence != null) 'confidence': confidence,
      'createdAt': createdAt.toJson(),
      if (reminder != null) 'reminder': reminder?.toJson(),
      if (recording != null) 'recording': recording?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'InboxItem',
      if (id != null) 'id': id,
      'userId': userId.toJson(),
      'type': type,
      'title': title,
      if (body != null) 'body': body,
      if (tags != null) 'tags': tags?.toJson(),
      if (priority != null) 'priority': priority,
      if (emoji != null) 'emoji': emoji,
      if (dueDate != null) 'dueDate': dueDate?.toJson(),
      'redactedTranscript': redactedTranscript,
      'isCompleted': isCompleted,
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      if (confidence != null) 'confidence': confidence,
      'createdAt': createdAt.toJson(),
      if (reminder != null) 'reminder': reminder?.toJsonForProtocol(),
      if (recording != null) 'recording': recording?.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _InboxItemImpl extends InboxItem {
  _InboxItemImpl({
    int? id,
    required _isc.UuidValue userId,
    required String type,
    required String title,
    String? body,
    List<String>? tags,
    String? priority,
    String? emoji,
    DateTime? dueDate,
    required String redactedTranscript,
    bool? isCompleted,
    DateTime? completedAt,
    double? confidence,
    required DateTime createdAt,
    _ic7cmrsw.Reminder? reminder,
    _ih2awd28.Recording? recording,
  }) : super._(
         id: id,
         userId: userId,
         type: type,
         title: title,
         body: body,
         tags: tags,
         priority: priority,
         emoji: emoji,
         dueDate: dueDate,
         redactedTranscript: redactedTranscript,
         isCompleted: isCompleted,
         completedAt: completedAt,
         confidence: confidence,
         createdAt: createdAt,
         reminder: reminder,
         recording: recording,
       );

  /// Returns a shallow copy of this [InboxItem]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  InboxItem copyWith({
    Object? id = _Undefined,
    _isc.UuidValue? userId,
    String? type,
    String? title,
    Object? body = _Undefined,
    Object? tags = _Undefined,
    Object? priority = _Undefined,
    Object? emoji = _Undefined,
    Object? dueDate = _Undefined,
    String? redactedTranscript,
    bool? isCompleted,
    Object? completedAt = _Undefined,
    Object? confidence = _Undefined,
    DateTime? createdAt,
    Object? reminder = _Undefined,
    Object? recording = _Undefined,
  }) {
    return InboxItem(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body is String? ? body : this.body,
      tags: tags is List<String>? ? tags : this.tags?.map((e0) => e0).toList(),
      priority: priority is String? ? priority : this.priority,
      emoji: emoji is String? ? emoji : this.emoji,
      dueDate: dueDate is DateTime? ? dueDate : this.dueDate,
      redactedTranscript: redactedTranscript ?? this.redactedTranscript,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
      confidence: confidence is double? ? confidence : this.confidence,
      createdAt: createdAt ?? this.createdAt,
      reminder: reminder is _ic7cmrsw.Reminder?
          ? reminder
          : this.reminder?.copyWith(),
      recording: recording is _ih2awd28.Recording?
          ? recording
          : this.recording?.copyWith(),
    );
  }
}
