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

abstract class VoiceCommandLog
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  VoiceCommandLog._({
    this.id,
    required this.eventId,
    required this.deviceId,
    required this.intent,
    this.actionTarget,
    required this.resultType,
    this.executionLatencyMs,
    required this.executedOffline,
    required this.syncedAt,
    this.transcript,
  });

  factory VoiceCommandLog({
    int? id,
    required String eventId,
    required String deviceId,
    required String intent,
    String? actionTarget,
    required String resultType,
    int? executionLatencyMs,
    required bool executedOffline,
    required DateTime syncedAt,
    String? transcript,
  }) = _VoiceCommandLogImpl;

  factory VoiceCommandLog.fromJson(Map<String, dynamic> jsonSerialization) {
    return VoiceCommandLog(
      id: jsonSerialization['id'] as int?,
      eventId: jsonSerialization['eventId'] as String,
      deviceId: jsonSerialization['deviceId'] as String,
      intent: jsonSerialization['intent'] as String,
      actionTarget: jsonSerialization['actionTarget'] as String?,
      resultType: jsonSerialization['resultType'] as String,
      executionLatencyMs: jsonSerialization['executionLatencyMs'] as int?,
      executedOffline: _is.BoolJsonExtension.fromJson(
        jsonSerialization['executedOffline'],
      ),
      syncedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['syncedAt'],
      ),
      transcript: jsonSerialization['transcript'] as String?,
    );
  }

  static final t = VoiceCommandLogTable();

  static const db = VoiceCommandLogRepository._();

  @override
  int? id;

  String eventId;

  String deviceId;

  String intent;

  String? actionTarget;

  String resultType;

  int? executionLatencyMs;

  bool executedOffline;

  DateTime syncedAt;

  String? transcript;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [VoiceCommandLog]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  VoiceCommandLog copyWith({
    int? id,
    String? eventId,
    String? deviceId,
    String? intent,
    String? actionTarget,
    String? resultType,
    int? executionLatencyMs,
    bool? executedOffline,
    DateTime? syncedAt,
    String? transcript,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'VoiceCommandLog',
      if (id != null) 'id': id,
      'eventId': eventId,
      'deviceId': deviceId,
      'intent': intent,
      if (actionTarget != null) 'actionTarget': actionTarget,
      'resultType': resultType,
      if (executionLatencyMs != null) 'executionLatencyMs': executionLatencyMs,
      'executedOffline': executedOffline,
      'syncedAt': syncedAt.toJson(),
      if (transcript != null) 'transcript': transcript,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'VoiceCommandLog',
      if (id != null) 'id': id,
      'eventId': eventId,
      'deviceId': deviceId,
      'intent': intent,
      if (actionTarget != null) 'actionTarget': actionTarget,
      'resultType': resultType,
      if (executionLatencyMs != null) 'executionLatencyMs': executionLatencyMs,
      'executedOffline': executedOffline,
      'syncedAt': syncedAt.toJson(),
      if (transcript != null) 'transcript': transcript,
    };
  }

  static VoiceCommandLogInclude include() {
    return VoiceCommandLogInclude._();
  }

  static VoiceCommandLogIncludeList includeList({
    _is.WhereExpressionBuilder<VoiceCommandLogTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<VoiceCommandLogTable>? orderBy,
    _is.OrderByListBuilder<VoiceCommandLogTable>? orderByList,
    VoiceCommandLogInclude? include,
  }) {
    return VoiceCommandLogIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(VoiceCommandLog.t),
      orderByList: orderByList?.call(VoiceCommandLog.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _VoiceCommandLogImpl extends VoiceCommandLog {
  _VoiceCommandLogImpl({
    int? id,
    required String eventId,
    required String deviceId,
    required String intent,
    String? actionTarget,
    required String resultType,
    int? executionLatencyMs,
    required bool executedOffline,
    required DateTime syncedAt,
    String? transcript,
  }) : super._(
         id: id,
         eventId: eventId,
         deviceId: deviceId,
         intent: intent,
         actionTarget: actionTarget,
         resultType: resultType,
         executionLatencyMs: executionLatencyMs,
         executedOffline: executedOffline,
         syncedAt: syncedAt,
         transcript: transcript,
       );

  /// Returns a shallow copy of this [VoiceCommandLog]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  VoiceCommandLog copyWith({
    Object? id = _Undefined,
    String? eventId,
    String? deviceId,
    String? intent,
    Object? actionTarget = _Undefined,
    String? resultType,
    Object? executionLatencyMs = _Undefined,
    bool? executedOffline,
    DateTime? syncedAt,
    Object? transcript = _Undefined,
  }) {
    return VoiceCommandLog(
      id: id is int? ? id : this.id,
      eventId: eventId ?? this.eventId,
      deviceId: deviceId ?? this.deviceId,
      intent: intent ?? this.intent,
      actionTarget: actionTarget is String? ? actionTarget : this.actionTarget,
      resultType: resultType ?? this.resultType,
      executionLatencyMs: executionLatencyMs is int?
          ? executionLatencyMs
          : this.executionLatencyMs,
      executedOffline: executedOffline ?? this.executedOffline,
      syncedAt: syncedAt ?? this.syncedAt,
      transcript: transcript is String? ? transcript : this.transcript,
    );
  }
}

class VoiceCommandLogUpdateTable extends _is.UpdateTable<VoiceCommandLogTable> {
  VoiceCommandLogUpdateTable(super.table);

  _is.ColumnValue<String, String> eventId(String value) => _is.ColumnValue(
    table.eventId,
    value,
  );

  _is.ColumnValue<String, String> deviceId(String value) => _is.ColumnValue(
    table.deviceId,
    value,
  );

  _is.ColumnValue<String, String> intent(String value) => _is.ColumnValue(
    table.intent,
    value,
  );

  _is.ColumnValue<String, String> actionTarget(String? value) =>
      _is.ColumnValue(
        table.actionTarget,
        value,
      );

  _is.ColumnValue<String, String> resultType(String value) => _is.ColumnValue(
    table.resultType,
    value,
  );

  _is.ColumnValue<int, int> executionLatencyMs(int? value) => _is.ColumnValue(
    table.executionLatencyMs,
    value,
  );

  _is.ColumnValue<bool, bool> executedOffline(bool value) => _is.ColumnValue(
    table.executedOffline,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> syncedAt(DateTime value) =>
      _is.ColumnValue(
        table.syncedAt,
        value,
      );

  _is.ColumnValue<String, String> transcript(String? value) => _is.ColumnValue(
    table.transcript,
    value,
  );
}

class VoiceCommandLogTable extends _is.Table<int?> {
  VoiceCommandLogTable({super.tableRelation})
    : super(tableName: 'voice_command_logs') {
    updateTable = VoiceCommandLogUpdateTable(this);
    eventId = _is.ColumnString(
      'eventId',
      this,
    );
    deviceId = _is.ColumnString(
      'deviceId',
      this,
    );
    intent = _is.ColumnString(
      'intent',
      this,
    );
    actionTarget = _is.ColumnString(
      'actionTarget',
      this,
    );
    resultType = _is.ColumnString(
      'resultType',
      this,
    );
    executionLatencyMs = _is.ColumnInt(
      'executionLatencyMs',
      this,
    );
    executedOffline = _is.ColumnBool(
      'executedOffline',
      this,
    );
    syncedAt = _is.ColumnDateTime(
      'syncedAt',
      this,
    );
    transcript = _is.ColumnString(
      'transcript',
      this,
    );
  }

  late final VoiceCommandLogUpdateTable updateTable;

  late final _is.ColumnString eventId;

  late final _is.ColumnString deviceId;

  late final _is.ColumnString intent;

  late final _is.ColumnString actionTarget;

  late final _is.ColumnString resultType;

  late final _is.ColumnInt executionLatencyMs;

  late final _is.ColumnBool executedOffline;

  late final _is.ColumnDateTime syncedAt;

  late final _is.ColumnString transcript;

  @override
  List<_is.Column> get columns => [
    id,
    eventId,
    deviceId,
    intent,
    actionTarget,
    resultType,
    executionLatencyMs,
    executedOffline,
    syncedAt,
    transcript,
  ];
}

class VoiceCommandLogInclude extends _is.IncludeObject {
  VoiceCommandLogInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => VoiceCommandLog.t;
}

class VoiceCommandLogIncludeList extends _is.IncludeList {
  VoiceCommandLogIncludeList._({
    _is.WhereExpressionBuilder<VoiceCommandLogTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(VoiceCommandLog.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => VoiceCommandLog.t;
}

class VoiceCommandLogRepository {
  const VoiceCommandLogRepository._();

  /// Returns a list of [VoiceCommandLog]s matching the given query parameters.
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
  Future<List<VoiceCommandLog>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<VoiceCommandLogTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<VoiceCommandLogTable>? orderBy,
    _is.OrderByListBuilder<VoiceCommandLogTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<VoiceCommandLog>(
      where: where?.call(VoiceCommandLog.t),
      orderBy: orderBy?.call(VoiceCommandLog.t),
      orderByList: orderByList?.call(VoiceCommandLog.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [VoiceCommandLog] matching the given query parameters.
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
  Future<VoiceCommandLog?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<VoiceCommandLogTable>? where,
    int? offset,
    _is.OrderByBuilder<VoiceCommandLogTable>? orderBy,
    _is.OrderByListBuilder<VoiceCommandLogTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<VoiceCommandLog>(
      where: where?.call(VoiceCommandLog.t),
      orderBy: orderBy?.call(VoiceCommandLog.t),
      orderByList: orderByList?.call(VoiceCommandLog.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [VoiceCommandLog] by its [id] or null if no such row exists.
  Future<VoiceCommandLog?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<VoiceCommandLog>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [VoiceCommandLog]s in the list and returns the inserted rows.
  ///
  /// The returned [VoiceCommandLog]s will have their `id` fields set.
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
  Future<List<VoiceCommandLog>> insert(
    _is.DatabaseSession session,
    List<VoiceCommandLog> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<VoiceCommandLog>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [VoiceCommandLog] and returns the inserted row.
  ///
  /// The returned [VoiceCommandLog] will have its `id` field set.
  Future<VoiceCommandLog> insertRow(
    _is.DatabaseSession session,
    VoiceCommandLog row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<VoiceCommandLog>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [VoiceCommandLog]s in the list and returns the resulting rows.
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
  /// The returned [VoiceCommandLog]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<VoiceCommandLog>> upsert(
    _is.DatabaseSession session,
    List<VoiceCommandLog> rows, {
    required _is.ColumnSelections<VoiceCommandLogTable> conflictColumns,
    _is.ColumnSelections<VoiceCommandLogTable>? updateColumns,
    _is.WhereExpressionBuilder<VoiceCommandLogTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<VoiceCommandLog>(
      rows,
      conflictColumns: conflictColumns(VoiceCommandLog.t),
      updateColumns: updateColumns?.call(VoiceCommandLog.t),
      updateWhere: updateWhere?.call(VoiceCommandLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [VoiceCommandLog] and returns the resulting row.
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
  /// The returned [VoiceCommandLog] will have its `id` field set.
  Future<VoiceCommandLog?> upsertRow(
    _is.DatabaseSession session,
    VoiceCommandLog row, {
    required _is.ColumnSelections<VoiceCommandLogTable> conflictColumns,
    _is.ColumnSelections<VoiceCommandLogTable>? updateColumns,
    _is.WhereExpressionBuilder<VoiceCommandLogTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<VoiceCommandLog>(
      row,
      conflictColumns: conflictColumns(VoiceCommandLog.t),
      updateColumns: updateColumns?.call(VoiceCommandLog.t),
      updateWhere: updateWhere?.call(VoiceCommandLog.t),
      transaction: transaction,
    );
  }

  /// Updates all [VoiceCommandLog]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<VoiceCommandLog>> update(
    _is.DatabaseSession session,
    List<VoiceCommandLog> rows, {
    _is.ColumnSelections<VoiceCommandLogTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<VoiceCommandLog>(
      rows,
      columns: columns?.call(VoiceCommandLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [VoiceCommandLog]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<VoiceCommandLog> updateRow(
    _is.DatabaseSession session,
    VoiceCommandLog row, {
    _is.ColumnSelections<VoiceCommandLogTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<VoiceCommandLog>(
      row,
      columns: columns?.call(VoiceCommandLog.t),
      transaction: transaction,
    );
  }

  /// Updates a single [VoiceCommandLog] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<VoiceCommandLog?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<VoiceCommandLogUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<VoiceCommandLog>(
      id,
      columnValues: columnValues(VoiceCommandLog.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [VoiceCommandLog]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<VoiceCommandLog>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<VoiceCommandLogUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<VoiceCommandLogTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<VoiceCommandLogTable>? orderBy,
    _is.OrderByListBuilder<VoiceCommandLogTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<VoiceCommandLog>(
      columnValues: columnValues(VoiceCommandLog.t.updateTable),
      where: where(VoiceCommandLog.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(VoiceCommandLog.t),
      orderByList: orderByList?.call(VoiceCommandLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [VoiceCommandLog]s in the list and returns the deleted rows.
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
  Future<List<VoiceCommandLog>> delete(
    _is.DatabaseSession session,
    List<VoiceCommandLog> rows, {
    _is.OrderByBuilder<VoiceCommandLogTable>? orderBy,
    _is.OrderByListBuilder<VoiceCommandLogTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<VoiceCommandLog>(
      rows,
      orderBy: orderBy?.call(VoiceCommandLog.t),
      orderByList: orderByList?.call(VoiceCommandLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [VoiceCommandLog].
  Future<VoiceCommandLog> deleteRow(
    _is.DatabaseSession session,
    VoiceCommandLog row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<VoiceCommandLog>(
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
  Future<List<VoiceCommandLog>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<VoiceCommandLogTable> where,
    _is.OrderByBuilder<VoiceCommandLogTable>? orderBy,
    _is.OrderByListBuilder<VoiceCommandLogTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<VoiceCommandLog>(
      where: where(VoiceCommandLog.t),
      orderBy: orderBy?.call(VoiceCommandLog.t),
      orderByList: orderByList?.call(VoiceCommandLog.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<VoiceCommandLogTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<VoiceCommandLog>(
      where: where?.call(VoiceCommandLog.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [VoiceCommandLog] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<VoiceCommandLogTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<VoiceCommandLog>(
      where: where(VoiceCommandLog.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
