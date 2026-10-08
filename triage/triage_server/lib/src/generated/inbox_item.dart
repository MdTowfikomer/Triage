/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_null_comparison

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _is;
import 'package:triage_server/src/generated/protocol.dart' as _ishkju68;
import 'recording.dart' as _ih2awd28;
import 'reminder.dart' as _ic7cmrsw;

abstract class InboxItem
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
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
    required _is.UuidValue userId,
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
      userId: _is.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
      type: jsonSerialization['type'] as String,
      title: jsonSerialization['title'] as String,
      body: jsonSerialization['body'] as String?,
      tags: jsonSerialization['tags'] == null
          ? null
          : _ishkju68.Protocol().deserialize<List<String>>(
              jsonSerialization['tags'],
            ),
      priority: jsonSerialization['priority'] as String?,
      emoji: jsonSerialization['emoji'] as String?,
      dueDate: jsonSerialization['dueDate'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['dueDate']),
      redactedTranscript: jsonSerialization['redactedTranscript'] as String,
      isCompleted: jsonSerialization['isCompleted'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['isCompleted']),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      confidence: (jsonSerialization['confidence'] as num?)?.toDouble(),
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      reminder: jsonSerialization['reminder'] == null
          ? null
          : _ishkju68.Protocol().deserialize<_ic7cmrsw.Reminder>(
              jsonSerialization['reminder'],
            ),
      recording: jsonSerialization['recording'] == null
          ? null
          : _ishkju68.Protocol().deserialize<_ih2awd28.Recording>(
              jsonSerialization['recording'],
            ),
    );
  }

  static final t = InboxItemTable();

  static const db = InboxItemRepository._();

  @override
  int? id;

  _is.UuidValue userId;

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

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [InboxItem]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  InboxItem copyWith({
    int? id,
    _is.UuidValue? userId,
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

  static InboxItemInclude include({
    _ic7cmrsw.ReminderInclude? reminder,
    _ih2awd28.RecordingInclude? recording,
  }) {
    return InboxItemInclude._(
      reminder: reminder,
      recording: recording,
    );
  }

  static InboxItemIncludeList includeList({
    _is.WhereExpressionBuilder<InboxItemTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<InboxItemTable>? orderBy,
    _is.OrderByListBuilder<InboxItemTable>? orderByList,
    InboxItemInclude? include,
  }) {
    return InboxItemIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(InboxItem.t),
      orderByList: orderByList?.call(InboxItem.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _InboxItemImpl extends InboxItem {
  _InboxItemImpl({
    int? id,
    required _is.UuidValue userId,
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
  @_is.useResult
  @override
  InboxItem copyWith({
    Object? id = _Undefined,
    _is.UuidValue? userId,
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

class InboxItemUpdateTable extends _is.UpdateTable<InboxItemTable> {
  InboxItemUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> userId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.userId,
        value,
      );

  _is.ColumnValue<String, String> type(String value) => _is.ColumnValue(
    table.type,
    value,
  );

  _is.ColumnValue<String, String> title(String value) => _is.ColumnValue(
    table.title,
    value,
  );

  _is.ColumnValue<String, String> body(String? value) => _is.ColumnValue(
    table.body,
    value,
  );

  _is.ColumnValue<List<String>, List<String>> tags(List<String>? value) =>
      _is.ColumnValue(
        table.tags,
        value,
      );

  _is.ColumnValue<String, String> priority(String? value) => _is.ColumnValue(
    table.priority,
    value,
  );

  _is.ColumnValue<String, String> emoji(String? value) => _is.ColumnValue(
    table.emoji,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> dueDate(DateTime? value) =>
      _is.ColumnValue(
        table.dueDate,
        value,
      );

  _is.ColumnValue<String, String> redactedTranscript(String value) =>
      _is.ColumnValue(
        table.redactedTranscript,
        value,
      );

  _is.ColumnValue<bool, bool> isCompleted(bool value) => _is.ColumnValue(
    table.isCompleted,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> completedAt(DateTime? value) =>
      _is.ColumnValue(
        table.completedAt,
        value,
      );

  _is.ColumnValue<double, double> confidence(double? value) => _is.ColumnValue(
    table.confidence,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class InboxItemTable extends _is.Table<int?> {
  InboxItemTable({super.tableRelation}) : super(tableName: 'inbox_items') {
    updateTable = InboxItemUpdateTable(this);
    userId = _is.ColumnUuid(
      'userId',
      this,
    );
    type = _is.ColumnString(
      'type',
      this,
    );
    title = _is.ColumnString(
      'title',
      this,
    );
    body = _is.ColumnString(
      'body',
      this,
    );
    tags = _is.ColumnSerializable<List<String>>(
      'tags',
      this,
    );
    priority = _is.ColumnString(
      'priority',
      this,
    );
    emoji = _is.ColumnString(
      'emoji',
      this,
    );
    dueDate = _is.ColumnDateTime(
      'dueDate',
      this,
    );
    redactedTranscript = _is.ColumnString(
      'redactedTranscript',
      this,
    );
    isCompleted = _is.ColumnBool(
      'isCompleted',
      this,
    );
    completedAt = _is.ColumnDateTime(
      'completedAt',
      this,
    );
    confidence = _is.ColumnDouble(
      'confidence',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final InboxItemUpdateTable updateTable;

  late final _is.ColumnUuid userId;

  late final _is.ColumnString type;

  late final _is.ColumnString title;

  late final _is.ColumnString body;

  late final _is.ColumnSerializable<List<String>> tags;

  late final _is.ColumnString priority;

  late final _is.ColumnString emoji;

  late final _is.ColumnDateTime dueDate;

  late final _is.ColumnString redactedTranscript;

  late final _is.ColumnBool isCompleted;

  late final _is.ColumnDateTime completedAt;

  late final _is.ColumnDouble confidence;

  late final _is.ColumnDateTime createdAt;

  _ic7cmrsw.ReminderTable? _reminder;

  _ih2awd28.RecordingTable? _recording;

  _ic7cmrsw.ReminderTable get reminder {
    if (_reminder != null) return _reminder!;
    _reminder = _is.createRelationTable(
      relationFieldName: 'reminder',
      field: InboxItem.t.id,
      foreignField: _ic7cmrsw.Reminder.t.inboxItemId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _ic7cmrsw.ReminderTable(tableRelation: foreignTableRelation),
    );
    return _reminder!;
  }

  _ih2awd28.RecordingTable get recording {
    if (_recording != null) return _recording!;
    _recording = _is.createRelationTable(
      relationFieldName: 'recording',
      field: InboxItem.t.id,
      foreignField: _ih2awd28.Recording.t.inboxItemId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _ih2awd28.RecordingTable(tableRelation: foreignTableRelation),
    );
    return _recording!;
  }

  @override
  List<_is.Column> get columns => [
    id,
    userId,
    type,
    title,
    body,
    tags,
    priority,
    emoji,
    dueDate,
    redactedTranscript,
    isCompleted,
    completedAt,
    confidence,
    createdAt,
  ];

  @override
  _is.Table? getRelationTable(String relationField) {
    if (relationField == 'reminder') {
      return reminder;
    }
    if (relationField == 'recording') {
      return recording;
    }
    return null;
  }
}

class InboxItemInclude extends _is.IncludeObject {
  InboxItemInclude._({
    _ic7cmrsw.ReminderInclude? reminder,
    _ih2awd28.RecordingInclude? recording,
  }) {
    _reminder = reminder;
    _recording = recording;
  }

  _ic7cmrsw.ReminderInclude? _reminder;

  _ih2awd28.RecordingInclude? _recording;

  @override
  Map<String, _is.Include?> get includes => {
    'reminder': _reminder,
    'recording': _recording,
  };

  @override
  _is.Table<int?> get table => InboxItem.t;
}

class InboxItemIncludeList extends _is.IncludeList {
  InboxItemIncludeList._({
    _is.WhereExpressionBuilder<InboxItemTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(InboxItem.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => InboxItem.t;
}

class InboxItemRepository {
  const InboxItemRepository._();

  final attachRow = const InboxItemAttachRowRepository._();

  final detachRow = const InboxItemDetachRowRepository._();

  /// Returns a list of [InboxItem]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<InboxItem>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<InboxItemTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<InboxItemTable>? orderBy,
    _is.OrderByListBuilder<InboxItemTable>? orderByList,
    _is.Transaction? transaction,
    InboxItemInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<InboxItem>(
      where: where?.call(InboxItem.t),
      orderBy: orderBy?.call(InboxItem.t),
      orderByList: orderByList?.call(InboxItem.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [InboxItem] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<InboxItem?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<InboxItemTable>? where,
    int? offset,
    _is.OrderByBuilder<InboxItemTable>? orderBy,
    _is.OrderByListBuilder<InboxItemTable>? orderByList,
    _is.Transaction? transaction,
    InboxItemInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<InboxItem>(
      where: where?.call(InboxItem.t),
      orderBy: orderBy?.call(InboxItem.t),
      orderByList: orderByList?.call(InboxItem.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [InboxItem] by its [id] or null if no such row exists.
  Future<InboxItem?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    InboxItemInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<InboxItem>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [InboxItem]s in the list and returns the inserted rows.
  ///
  /// The returned [InboxItem]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<InboxItem>> insert(
    _is.DatabaseSession session,
    List<InboxItem> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<InboxItem>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [InboxItem] and returns the inserted row.
  ///
  /// The returned [InboxItem] will have its `id` field set.
  Future<InboxItem> insertRow(
    _is.DatabaseSession session,
    InboxItem row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<InboxItem>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [InboxItem]s in the list and returns the resulting rows.
  ///
  /// If a row conflicts on the given [conflictColumns], the existing row is
  /// updated with the new values. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies to rows matching the
  /// given expression. Conflicting rows that don't match are skipped and not
  /// returned, so the resulting list may be shorter than [rows].
  ///
  /// The returned [InboxItem]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<InboxItem>> upsert(
    _is.DatabaseSession session,
    List<InboxItem> rows, {
    required _is.ColumnSelections<InboxItemTable> conflictColumns,
    _is.ColumnSelections<InboxItemTable>? updateColumns,
    _is.WhereExpressionBuilder<InboxItemTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<InboxItem>(
      rows,
      conflictColumns: conflictColumns(InboxItem.t),
      updateColumns: updateColumns?.call(InboxItem.t),
      updateWhere: updateWhere?.call(InboxItem.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [InboxItem] and returns the resulting row.
  ///
  /// If the row conflicts on the given [conflictColumns], the existing row is
  /// updated. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies when the existing
  /// row matches the expression. Returns `null` if no row was affected — for
  /// example when [updateWhere] does not match the conflicting row.
  ///
  /// The returned [InboxItem] will have its `id` field set.
  Future<InboxItem?> upsertRow(
    _is.DatabaseSession session,
    InboxItem row, {
    required _is.ColumnSelections<InboxItemTable> conflictColumns,
    _is.ColumnSelections<InboxItemTable>? updateColumns,
    _is.WhereExpressionBuilder<InboxItemTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<InboxItem>(
      row,
      conflictColumns: conflictColumns(InboxItem.t),
      updateColumns: updateColumns?.call(InboxItem.t),
      updateWhere: updateWhere?.call(InboxItem.t),
      transaction: transaction,
    );
  }

  /// Updates all [InboxItem]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<InboxItem>> update(
    _is.DatabaseSession session,
    List<InboxItem> rows, {
    _is.ColumnSelections<InboxItemTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<InboxItem>(
      rows,
      columns: columns?.call(InboxItem.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [InboxItem]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<InboxItem> updateRow(
    _is.DatabaseSession session,
    InboxItem row, {
    _is.ColumnSelections<InboxItemTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<InboxItem>(
      row,
      columns: columns?.call(InboxItem.t),
      transaction: transaction,
    );
  }

  /// Updates a single [InboxItem] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<InboxItem?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<InboxItemUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<InboxItem>(
      id,
      columnValues: columnValues(InboxItem.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [InboxItem]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<InboxItem>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<InboxItemUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<InboxItemTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<InboxItemTable>? orderBy,
    _is.OrderByListBuilder<InboxItemTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<InboxItem>(
      columnValues: columnValues(InboxItem.t.updateTable),
      where: where(InboxItem.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(InboxItem.t),
      orderByList: orderByList?.call(InboxItem.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [InboxItem]s in the list and returns the deleted rows.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<InboxItem>> delete(
    _is.DatabaseSession session,
    List<InboxItem> rows, {
    _is.OrderByBuilder<InboxItemTable>? orderBy,
    _is.OrderByListBuilder<InboxItemTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<InboxItem>(
      rows,
      orderBy: orderBy?.call(InboxItem.t),
      orderByList: orderByList?.call(InboxItem.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [InboxItem].
  Future<InboxItem> deleteRow(
    _is.DatabaseSession session,
    InboxItem row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<InboxItem>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<InboxItem>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<InboxItemTable> where,
    _is.OrderByBuilder<InboxItemTable>? orderBy,
    _is.OrderByListBuilder<InboxItemTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<InboxItem>(
      where: where(InboxItem.t),
      orderBy: orderBy?.call(InboxItem.t),
      orderByList: orderByList?.call(InboxItem.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<InboxItemTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<InboxItem>(
      where: where?.call(InboxItem.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [InboxItem] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<InboxItemTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<InboxItem>(
      where: where(InboxItem.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class InboxItemAttachRowRepository {
  const InboxItemAttachRowRepository._();

  /// Creates a relation between the given [InboxItem] and [Reminder]
  /// by setting the [InboxItem]'s foreign key `id` to refer to the [Reminder].
  Future<void> reminder(
    _is.DatabaseSession session,
    InboxItem inboxItem,
    _ic7cmrsw.Reminder reminder, {
    _is.Transaction? transaction,
  }) async {
    if (reminder.id == null) {
      throw ArgumentError.notNull('reminder.id');
    }
    if (inboxItem.id == null) {
      throw ArgumentError.notNull('inboxItem.id');
    }

    var $reminder = reminder.copyWith(inboxItemId: inboxItem.id);
    await session.db.updateRow<_ic7cmrsw.Reminder>(
      $reminder,
      columns: [_ic7cmrsw.Reminder.t.inboxItemId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [InboxItem] and [Recording]
  /// by setting the [InboxItem]'s foreign key `id` to refer to the [Recording].
  Future<void> recording(
    _is.DatabaseSession session,
    InboxItem inboxItem,
    _ih2awd28.Recording recording, {
    _is.Transaction? transaction,
  }) async {
    if (recording.id == null) {
      throw ArgumentError.notNull('recording.id');
    }
    if (inboxItem.id == null) {
      throw ArgumentError.notNull('inboxItem.id');
    }

    var $recording = recording.copyWith(inboxItemId: inboxItem.id);
    await session.db.updateRow<_ih2awd28.Recording>(
      $recording,
      columns: [_ih2awd28.Recording.t.inboxItemId],
      transaction: transaction,
    );
  }
}

class InboxItemDetachRowRepository {
  const InboxItemDetachRowRepository._();

  /// Detaches the relation between this [InboxItem] and the [Reminder] set in `reminder`
  /// by setting the [InboxItem]'s foreign key `id` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> reminder(
    _is.DatabaseSession session,
    InboxItem inboxItem, {
    _is.Transaction? transaction,
  }) async {
    var $reminder = inboxItem.reminder;

    if ($reminder == null) {
      throw ArgumentError.notNull('inboxItem.reminder');
    }
    if ($reminder.id == null) {
      throw ArgumentError.notNull('inboxItem.reminder.id');
    }
    if (inboxItem.id == null) {
      throw ArgumentError.notNull('inboxItem.id');
    }

    var $$reminder = $reminder.copyWith(inboxItemId: null);
    await session.db.updateRow<_ic7cmrsw.Reminder>(
      $$reminder,
      columns: [_ic7cmrsw.Reminder.t.inboxItemId],
      transaction: transaction,
    );
  }

  /// Detaches the relation between this [InboxItem] and the [Recording] set in `recording`
  /// by setting the [InboxItem]'s foreign key `id` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> recording(
    _is.DatabaseSession session,
    InboxItem inboxItem, {
    _is.Transaction? transaction,
  }) async {
    var $recording = inboxItem.recording;

    if ($recording == null) {
      throw ArgumentError.notNull('inboxItem.recording');
    }
    if ($recording.id == null) {
      throw ArgumentError.notNull('inboxItem.recording.id');
    }
    if (inboxItem.id == null) {
      throw ArgumentError.notNull('inboxItem.id');
    }

    var $$recording = $recording.copyWith(inboxItemId: null);
    await session.db.updateRow<_ih2awd28.Recording>(
      $$recording,
      columns: [_ih2awd28.Recording.t.inboxItemId],
      transaction: transaction,
    );
  }
}
