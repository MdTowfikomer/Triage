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

abstract class RoutineSchedule
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  RoutineSchedule._({
    this.id,
    required this.routineId,
    required this.deviceId,
    required this.userId,
    required this.name,
    required this.scheduledTime,
    required this.stepsJson,
    required this.status,
    required this.createdAt,
    this.dispatchedAt,
    this.completedAt,
    this.lastError,
    this.lastOccurrenceId,
  });

  factory RoutineSchedule({
    int? id,
    required String routineId,
    required String deviceId,
    required _is.UuidValue userId,
    required String name,
    required DateTime scheduledTime,
    required String stepsJson,
    required String status,
    required DateTime createdAt,
    DateTime? dispatchedAt,
    DateTime? completedAt,
    String? lastError,
    String? lastOccurrenceId,
  }) = _RoutineScheduleImpl;

  factory RoutineSchedule.fromJson(Map<String, dynamic> jsonSerialization) {
    return RoutineSchedule(
      id: jsonSerialization['id'] as int?,
      routineId: jsonSerialization['routineId'] as String,
      deviceId: jsonSerialization['deviceId'] as String,
      userId: _is.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
      name: jsonSerialization['name'] as String,
      scheduledTime: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['scheduledTime'],
      ),
      stepsJson: jsonSerialization['stepsJson'] as String,
      status: jsonSerialization['status'] as String,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      dispatchedAt: jsonSerialization['dispatchedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['dispatchedAt'],
            ),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      lastError: jsonSerialization['lastError'] as String?,
      lastOccurrenceId: jsonSerialization['lastOccurrenceId'] as String?,
    );
  }

  static final t = RoutineScheduleTable();

  static const db = RoutineScheduleRepository._();

  @override
  int? id;

  String routineId;

  String deviceId;

  _is.UuidValue userId;

  String name;

  DateTime scheduledTime;

  String stepsJson;

  String status;

  DateTime createdAt;

  DateTime? dispatchedAt;

  DateTime? completedAt;

  String? lastError;

  String? lastOccurrenceId;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [RoutineSchedule]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  RoutineSchedule copyWith({
    int? id,
    String? routineId,
    String? deviceId,
    _is.UuidValue? userId,
    String? name,
    DateTime? scheduledTime,
    String? stepsJson,
    String? status,
    DateTime? createdAt,
    DateTime? dispatchedAt,
    DateTime? completedAt,
    String? lastError,
    String? lastOccurrenceId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RoutineSchedule',
      if (id != null) 'id': id,
      'routineId': routineId,
      'deviceId': deviceId,
      'userId': userId.toJson(),
      'name': name,
      'scheduledTime': scheduledTime.toJson(),
      'stepsJson': stepsJson,
      'status': status,
      'createdAt': createdAt.toJson(),
      if (dispatchedAt != null) 'dispatchedAt': dispatchedAt?.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      if (lastError != null) 'lastError': lastError,
      if (lastOccurrenceId != null) 'lastOccurrenceId': lastOccurrenceId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'RoutineSchedule',
      if (id != null) 'id': id,
      'routineId': routineId,
      'deviceId': deviceId,
      'userId': userId.toJson(),
      'name': name,
      'scheduledTime': scheduledTime.toJson(),
      'stepsJson': stepsJson,
      'status': status,
      'createdAt': createdAt.toJson(),
      if (dispatchedAt != null) 'dispatchedAt': dispatchedAt?.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      if (lastError != null) 'lastError': lastError,
      if (lastOccurrenceId != null) 'lastOccurrenceId': lastOccurrenceId,
    };
  }

  static RoutineScheduleInclude include() {
    return RoutineScheduleInclude._();
  }

  static RoutineScheduleIncludeList includeList({
    _is.WhereExpressionBuilder<RoutineScheduleTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<RoutineScheduleTable>? orderBy,
    _is.OrderByListBuilder<RoutineScheduleTable>? orderByList,
    RoutineScheduleInclude? include,
  }) {
    return RoutineScheduleIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(RoutineSchedule.t),
      orderByList: orderByList?.call(RoutineSchedule.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RoutineScheduleImpl extends RoutineSchedule {
  _RoutineScheduleImpl({
    int? id,
    required String routineId,
    required String deviceId,
    required _is.UuidValue userId,
    required String name,
    required DateTime scheduledTime,
    required String stepsJson,
    required String status,
    required DateTime createdAt,
    DateTime? dispatchedAt,
    DateTime? completedAt,
    String? lastError,
    String? lastOccurrenceId,
  }) : super._(
         id: id,
         routineId: routineId,
         deviceId: deviceId,
         userId: userId,
         name: name,
         scheduledTime: scheduledTime,
         stepsJson: stepsJson,
         status: status,
         createdAt: createdAt,
         dispatchedAt: dispatchedAt,
         completedAt: completedAt,
         lastError: lastError,
         lastOccurrenceId: lastOccurrenceId,
       );

  /// Returns a shallow copy of this [RoutineSchedule]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  RoutineSchedule copyWith({
    Object? id = _Undefined,
    String? routineId,
    String? deviceId,
    _is.UuidValue? userId,
    String? name,
    DateTime? scheduledTime,
    String? stepsJson,
    String? status,
    DateTime? createdAt,
    Object? dispatchedAt = _Undefined,
    Object? completedAt = _Undefined,
    Object? lastError = _Undefined,
    Object? lastOccurrenceId = _Undefined,
  }) {
    return RoutineSchedule(
      id: id is int? ? id : this.id,
      routineId: routineId ?? this.routineId,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      stepsJson: stepsJson ?? this.stepsJson,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dispatchedAt: dispatchedAt is DateTime?
          ? dispatchedAt
          : this.dispatchedAt,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
      lastError: lastError is String? ? lastError : this.lastError,
      lastOccurrenceId: lastOccurrenceId is String?
          ? lastOccurrenceId
          : this.lastOccurrenceId,
    );
  }
}

class RoutineScheduleUpdateTable extends _is.UpdateTable<RoutineScheduleTable> {
  RoutineScheduleUpdateTable(super.table);

  _is.ColumnValue<String, String> routineId(String value) => _is.ColumnValue(
    table.routineId,
    value,
  );

  _is.ColumnValue<String, String> deviceId(String value) => _is.ColumnValue(
    table.deviceId,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> userId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.userId,
        value,
      );

  _is.ColumnValue<String, String> name(String value) => _is.ColumnValue(
    table.name,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> scheduledTime(DateTime value) =>
      _is.ColumnValue(
        table.scheduledTime,
        value,
      );

  _is.ColumnValue<String, String> stepsJson(String value) => _is.ColumnValue(
    table.stepsJson,
    value,
  );

  _is.ColumnValue<String, String> status(String value) => _is.ColumnValue(
    table.status,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> dispatchedAt(DateTime? value) =>
      _is.ColumnValue(
        table.dispatchedAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> completedAt(DateTime? value) =>
      _is.ColumnValue(
        table.completedAt,
        value,
      );

  _is.ColumnValue<String, String> lastError(String? value) => _is.ColumnValue(
    table.lastError,
    value,
  );

  _is.ColumnValue<String, String> lastOccurrenceId(String? value) =>
      _is.ColumnValue(
        table.lastOccurrenceId,
        value,
      );
}

class RoutineScheduleTable extends _is.Table<int?> {
  RoutineScheduleTable({super.tableRelation})
    : super(tableName: 'routine_schedules') {
    updateTable = RoutineScheduleUpdateTable(this);
    routineId = _is.ColumnString(
      'routineId',
      this,
    );
    deviceId = _is.ColumnString(
      'deviceId',
      this,
    );
    userId = _is.ColumnUuid(
      'userId',
      this,
    );
    name = _is.ColumnString(
      'name',
      this,
    );
    scheduledTime = _is.ColumnDateTime(
      'scheduledTime',
      this,
    );
    stepsJson = _is.ColumnString(
      'stepsJson',
      this,
    );
    status = _is.ColumnString(
      'status',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    dispatchedAt = _is.ColumnDateTime(
      'dispatchedAt',
      this,
    );
    completedAt = _is.ColumnDateTime(
      'completedAt',
      this,
    );
    lastError = _is.ColumnString(
      'lastError',
      this,
    );
    lastOccurrenceId = _is.ColumnString(
      'lastOccurrenceId',
      this,
    );
  }

  late final RoutineScheduleUpdateTable updateTable;

  late final _is.ColumnString routineId;

  late final _is.ColumnString deviceId;

  late final _is.ColumnUuid userId;

  late final _is.ColumnString name;

  late final _is.ColumnDateTime scheduledTime;

  late final _is.ColumnString stepsJson;

  late final _is.ColumnString status;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime dispatchedAt;

  late final _is.ColumnDateTime completedAt;

  late final _is.ColumnString lastError;

  late final _is.ColumnString lastOccurrenceId;

  @override
  List<_is.Column> get columns => [
    id,
    routineId,
    deviceId,
    userId,
    name,
    scheduledTime,
    stepsJson,
    status,
    createdAt,
    dispatchedAt,
    completedAt,
    lastError,
    lastOccurrenceId,
  ];
}

class RoutineScheduleInclude extends _is.IncludeObject {
  RoutineScheduleInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => RoutineSchedule.t;
}

class RoutineScheduleIncludeList extends _is.IncludeList {
  RoutineScheduleIncludeList._({
    _is.WhereExpressionBuilder<RoutineScheduleTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(RoutineSchedule.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => RoutineSchedule.t;
}

class RoutineScheduleRepository {
  const RoutineScheduleRepository._();

  /// Returns a list of [RoutineSchedule]s matching the given query parameters.
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
  Future<List<RoutineSchedule>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<RoutineScheduleTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<RoutineScheduleTable>? orderBy,
    _is.OrderByListBuilder<RoutineScheduleTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<RoutineSchedule>(
      where: where?.call(RoutineSchedule.t),
      orderBy: orderBy?.call(RoutineSchedule.t),
      orderByList: orderByList?.call(RoutineSchedule.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [RoutineSchedule] matching the given query parameters.
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
  Future<RoutineSchedule?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<RoutineScheduleTable>? where,
    int? offset,
    _is.OrderByBuilder<RoutineScheduleTable>? orderBy,
    _is.OrderByListBuilder<RoutineScheduleTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<RoutineSchedule>(
      where: where?.call(RoutineSchedule.t),
      orderBy: orderBy?.call(RoutineSchedule.t),
      orderByList: orderByList?.call(RoutineSchedule.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [RoutineSchedule] by its [id] or null if no such row exists.
  Future<RoutineSchedule?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<RoutineSchedule>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [RoutineSchedule]s in the list and returns the inserted rows.
  ///
  /// The returned [RoutineSchedule]s will have their `id` fields set.
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
  Future<List<RoutineSchedule>> insert(
    _is.DatabaseSession session,
    List<RoutineSchedule> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<RoutineSchedule>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [RoutineSchedule] and returns the inserted row.
  ///
  /// The returned [RoutineSchedule] will have its `id` field set.
  Future<RoutineSchedule> insertRow(
    _is.DatabaseSession session,
    RoutineSchedule row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<RoutineSchedule>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [RoutineSchedule]s in the list and returns the resulting rows.
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
  /// The returned [RoutineSchedule]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<RoutineSchedule>> upsert(
    _is.DatabaseSession session,
    List<RoutineSchedule> rows, {
    required _is.ColumnSelections<RoutineScheduleTable> conflictColumns,
    _is.ColumnSelections<RoutineScheduleTable>? updateColumns,
    _is.WhereExpressionBuilder<RoutineScheduleTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<RoutineSchedule>(
      rows,
      conflictColumns: conflictColumns(RoutineSchedule.t),
      updateColumns: updateColumns?.call(RoutineSchedule.t),
      updateWhere: updateWhere?.call(RoutineSchedule.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [RoutineSchedule] and returns the resulting row.
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
  /// The returned [RoutineSchedule] will have its `id` field set.
  Future<RoutineSchedule?> upsertRow(
    _is.DatabaseSession session,
    RoutineSchedule row, {
    required _is.ColumnSelections<RoutineScheduleTable> conflictColumns,
    _is.ColumnSelections<RoutineScheduleTable>? updateColumns,
    _is.WhereExpressionBuilder<RoutineScheduleTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<RoutineSchedule>(
      row,
      conflictColumns: conflictColumns(RoutineSchedule.t),
      updateColumns: updateColumns?.call(RoutineSchedule.t),
      updateWhere: updateWhere?.call(RoutineSchedule.t),
      transaction: transaction,
    );
  }

  /// Updates all [RoutineSchedule]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<RoutineSchedule>> update(
    _is.DatabaseSession session,
    List<RoutineSchedule> rows, {
    _is.ColumnSelections<RoutineScheduleTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<RoutineSchedule>(
      rows,
      columns: columns?.call(RoutineSchedule.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [RoutineSchedule]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<RoutineSchedule> updateRow(
    _is.DatabaseSession session,
    RoutineSchedule row, {
    _is.ColumnSelections<RoutineScheduleTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<RoutineSchedule>(
      row,
      columns: columns?.call(RoutineSchedule.t),
      transaction: transaction,
    );
  }

  /// Updates a single [RoutineSchedule] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<RoutineSchedule?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<RoutineScheduleUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<RoutineSchedule>(
      id,
      columnValues: columnValues(RoutineSchedule.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [RoutineSchedule]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<RoutineSchedule>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<RoutineScheduleUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<RoutineScheduleTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<RoutineScheduleTable>? orderBy,
    _is.OrderByListBuilder<RoutineScheduleTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<RoutineSchedule>(
      columnValues: columnValues(RoutineSchedule.t.updateTable),
      where: where(RoutineSchedule.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(RoutineSchedule.t),
      orderByList: orderByList?.call(RoutineSchedule.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [RoutineSchedule]s in the list and returns the deleted rows.
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
  Future<List<RoutineSchedule>> delete(
    _is.DatabaseSession session,
    List<RoutineSchedule> rows, {
    _is.OrderByBuilder<RoutineScheduleTable>? orderBy,
    _is.OrderByListBuilder<RoutineScheduleTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<RoutineSchedule>(
      rows,
      orderBy: orderBy?.call(RoutineSchedule.t),
      orderByList: orderByList?.call(RoutineSchedule.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [RoutineSchedule].
  Future<RoutineSchedule> deleteRow(
    _is.DatabaseSession session,
    RoutineSchedule row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<RoutineSchedule>(
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
  Future<List<RoutineSchedule>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<RoutineScheduleTable> where,
    _is.OrderByBuilder<RoutineScheduleTable>? orderBy,
    _is.OrderByListBuilder<RoutineScheduleTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<RoutineSchedule>(
      where: where(RoutineSchedule.t),
      orderBy: orderBy?.call(RoutineSchedule.t),
      orderByList: orderByList?.call(RoutineSchedule.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<RoutineScheduleTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<RoutineSchedule>(
      where: where?.call(RoutineSchedule.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [RoutineSchedule] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<RoutineScheduleTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<RoutineSchedule>(
      where: where(RoutineSchedule.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
