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
import 'inbox_item.dart' as _iv6iq8qv;

abstract class Recording
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
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
          : _ishkju68.Protocol().deserialize<_iv6iq8qv.InboxItem>(
              jsonSerialization['inboxItem'],
            ),
      storageUrl: jsonSerialization['storageUrl'] as String,
      durationMs: jsonSerialization['durationMs'] as int,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = RecordingTable();

  static const db = RecordingRepository._();

  @override
  int? id;

  int inboxItemId;

  _iv6iq8qv.InboxItem? inboxItem;

  String storageUrl;

  int durationMs;

  DateTime createdAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [Recording]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
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

  static RecordingInclude include({_iv6iq8qv.InboxItemInclude? inboxItem}) {
    return RecordingInclude._(inboxItem: inboxItem);
  }

  static RecordingIncludeList includeList({
    _is.WhereExpressionBuilder<RecordingTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<RecordingTable>? orderBy,
    _is.OrderByListBuilder<RecordingTable>? orderByList,
    RecordingInclude? include,
  }) {
    return RecordingIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Recording.t),
      orderByList: orderByList?.call(Recording.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
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
  @_is.useResult
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

class RecordingUpdateTable extends _is.UpdateTable<RecordingTable> {
  RecordingUpdateTable(super.table);

  _is.ColumnValue<int, int> inboxItemId(int value) => _is.ColumnValue(
    table.inboxItemId,
    value,
  );

  _is.ColumnValue<String, String> storageUrl(String value) => _is.ColumnValue(
    table.storageUrl,
    value,
  );

  _is.ColumnValue<int, int> durationMs(int value) => _is.ColumnValue(
    table.durationMs,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class RecordingTable extends _is.Table<int?> {
  RecordingTable({super.tableRelation}) : super(tableName: 'recordings') {
    updateTable = RecordingUpdateTable(this);
    inboxItemId = _is.ColumnInt(
      'inboxItemId',
      this,
    );
    storageUrl = _is.ColumnString(
      'storageUrl',
      this,
    );
    durationMs = _is.ColumnInt(
      'durationMs',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final RecordingUpdateTable updateTable;

  late final _is.ColumnInt inboxItemId;

  _iv6iq8qv.InboxItemTable? _inboxItem;

  late final _is.ColumnString storageUrl;

  late final _is.ColumnInt durationMs;

  late final _is.ColumnDateTime createdAt;

  _iv6iq8qv.InboxItemTable get inboxItem {
    if (_inboxItem != null) return _inboxItem!;
    _inboxItem = _is.createRelationTable(
      relationFieldName: 'inboxItem',
      field: Recording.t.inboxItemId,
      foreignField: _iv6iq8qv.InboxItem.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _iv6iq8qv.InboxItemTable(tableRelation: foreignTableRelation),
    );
    return _inboxItem!;
  }

  @override
  List<_is.Column> get columns => [
    id,
    inboxItemId,
    storageUrl,
    durationMs,
    createdAt,
  ];

  @override
  _is.Table? getRelationTable(String relationField) {
    if (relationField == 'inboxItem') {
      return inboxItem;
    }
    return null;
  }
}

class RecordingInclude extends _is.IncludeObject {
  RecordingInclude._({_iv6iq8qv.InboxItemInclude? inboxItem}) {
    _inboxItem = inboxItem;
  }

  _iv6iq8qv.InboxItemInclude? _inboxItem;

  @override
  Map<String, _is.Include?> get includes => {'inboxItem': _inboxItem};

  @override
  _is.Table<int?> get table => Recording.t;
}

class RecordingIncludeList extends _is.IncludeList {
  RecordingIncludeList._({
    _is.WhereExpressionBuilder<RecordingTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Recording.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => Recording.t;
}

class RecordingRepository {
  const RecordingRepository._();

  final attachRow = const RecordingAttachRowRepository._();

  /// Returns a list of [Recording]s matching the given query parameters.
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
  Future<List<Recording>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<RecordingTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<RecordingTable>? orderBy,
    _is.OrderByListBuilder<RecordingTable>? orderByList,
    _is.Transaction? transaction,
    RecordingInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Recording>(
      where: where?.call(Recording.t),
      orderBy: orderBy?.call(Recording.t),
      orderByList: orderByList?.call(Recording.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [Recording] matching the given query parameters.
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
  Future<Recording?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<RecordingTable>? where,
    int? offset,
    _is.OrderByBuilder<RecordingTable>? orderBy,
    _is.OrderByListBuilder<RecordingTable>? orderByList,
    _is.Transaction? transaction,
    RecordingInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Recording>(
      where: where?.call(Recording.t),
      orderBy: orderBy?.call(Recording.t),
      orderByList: orderByList?.call(Recording.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Recording] by its [id] or null if no such row exists.
  Future<Recording?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    RecordingInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Recording>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Recording]s in the list and returns the inserted rows.
  ///
  /// The returned [Recording]s will have their `id` fields set.
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
  Future<List<Recording>> insert(
    _is.DatabaseSession session,
    List<Recording> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Recording>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Recording] and returns the inserted row.
  ///
  /// The returned [Recording] will have its `id` field set.
  Future<Recording> insertRow(
    _is.DatabaseSession session,
    Recording row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<Recording>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Recording]s in the list and returns the resulting rows.
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
  /// The returned [Recording]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Recording>> upsert(
    _is.DatabaseSession session,
    List<Recording> rows, {
    required _is.ColumnSelections<RecordingTable> conflictColumns,
    _is.ColumnSelections<RecordingTable>? updateColumns,
    _is.WhereExpressionBuilder<RecordingTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Recording>(
      rows,
      conflictColumns: conflictColumns(Recording.t),
      updateColumns: updateColumns?.call(Recording.t),
      updateWhere: updateWhere?.call(Recording.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Recording] and returns the resulting row.
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
  /// The returned [Recording] will have its `id` field set.
  Future<Recording?> upsertRow(
    _is.DatabaseSession session,
    Recording row, {
    required _is.ColumnSelections<RecordingTable> conflictColumns,
    _is.ColumnSelections<RecordingTable>? updateColumns,
    _is.WhereExpressionBuilder<RecordingTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Recording>(
      row,
      conflictColumns: conflictColumns(Recording.t),
      updateColumns: updateColumns?.call(Recording.t),
      updateWhere: updateWhere?.call(Recording.t),
      transaction: transaction,
    );
  }

  /// Updates all [Recording]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Recording>> update(
    _is.DatabaseSession session,
    List<Recording> rows, {
    _is.ColumnSelections<RecordingTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Recording>(
      rows,
      columns: columns?.call(Recording.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Recording]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Recording> updateRow(
    _is.DatabaseSession session,
    Recording row, {
    _is.ColumnSelections<RecordingTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<Recording>(
      row,
      columns: columns?.call(Recording.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Recording] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Recording?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<RecordingUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<Recording>(
      id,
      columnValues: columnValues(Recording.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Recording]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Recording>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<RecordingUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<RecordingTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<RecordingTable>? orderBy,
    _is.OrderByListBuilder<RecordingTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Recording>(
      columnValues: columnValues(Recording.t.updateTable),
      where: where(Recording.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Recording.t),
      orderByList: orderByList?.call(Recording.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Recording]s in the list and returns the deleted rows.
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
  Future<List<Recording>> delete(
    _is.DatabaseSession session,
    List<Recording> rows, {
    _is.OrderByBuilder<RecordingTable>? orderBy,
    _is.OrderByListBuilder<RecordingTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Recording>(
      rows,
      orderBy: orderBy?.call(Recording.t),
      orderByList: orderByList?.call(Recording.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Recording].
  Future<Recording> deleteRow(
    _is.DatabaseSession session,
    Recording row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Recording>(
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
  Future<List<Recording>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<RecordingTable> where,
    _is.OrderByBuilder<RecordingTable>? orderBy,
    _is.OrderByListBuilder<RecordingTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Recording>(
      where: where(Recording.t),
      orderBy: orderBy?.call(Recording.t),
      orderByList: orderByList?.call(Recording.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<RecordingTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<Recording>(
      where: where?.call(Recording.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Recording] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<RecordingTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Recording>(
      where: where(Recording.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class RecordingAttachRowRepository {
  const RecordingAttachRowRepository._();

  /// Creates a relation between the given [Recording] and [InboxItem]
  /// by setting the [Recording]'s foreign key `inboxItemId` to refer to the [InboxItem].
  Future<void> inboxItem(
    _is.DatabaseSession session,
    Recording recording,
    _iv6iq8qv.InboxItem inboxItem, {
    _is.Transaction? transaction,
  }) async {
    if (recording.id == null) {
      throw ArgumentError.notNull('recording.id');
    }
    if (inboxItem.id == null) {
      throw ArgumentError.notNull('inboxItem.id');
    }

    var $recording = recording.copyWith(inboxItemId: inboxItem.id);
    await session.db.updateRow<Recording>(
      $recording,
      columns: [Recording.t.inboxItemId],
      transaction: transaction,
    );
  }
}
