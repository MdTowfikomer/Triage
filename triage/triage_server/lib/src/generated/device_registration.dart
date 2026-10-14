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

abstract class DeviceRegistration
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  DeviceRegistration._({
    this.id,
    required this.deviceId,
    required this.userId,
    required this.deviceToken,
    this.deviceName,
    required this.registeredAt,
    this.lastSeenAt,
  });

  factory DeviceRegistration({
    int? id,
    required String deviceId,
    required _is.UuidValue userId,
    required String deviceToken,
    String? deviceName,
    required DateTime registeredAt,
    DateTime? lastSeenAt,
  }) = _DeviceRegistrationImpl;

  factory DeviceRegistration.fromJson(Map<String, dynamic> jsonSerialization) {
    return DeviceRegistration(
      id: jsonSerialization['id'] as int?,
      deviceId: jsonSerialization['deviceId'] as String,
      userId: _is.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
      deviceToken: jsonSerialization['deviceToken'] as String,
      deviceName: jsonSerialization['deviceName'] as String?,
      registeredAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['registeredAt'],
      ),
      lastSeenAt: jsonSerialization['lastSeenAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['lastSeenAt']),
    );
  }

  static final t = DeviceRegistrationTable();

  static const db = DeviceRegistrationRepository._();

  @override
  int? id;

  String deviceId;

  _is.UuidValue userId;

  String deviceToken;

  String? deviceName;

  DateTime registeredAt;

  DateTime? lastSeenAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [DeviceRegistration]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DeviceRegistration copyWith({
    int? id,
    String? deviceId,
    _is.UuidValue? userId,
    String? deviceToken,
    String? deviceName,
    DateTime? registeredAt,
    DateTime? lastSeenAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DeviceRegistration',
      if (id != null) 'id': id,
      'deviceId': deviceId,
      'userId': userId.toJson(),
      'deviceToken': deviceToken,
      if (deviceName != null) 'deviceName': deviceName,
      'registeredAt': registeredAt.toJson(),
      if (lastSeenAt != null) 'lastSeenAt': lastSeenAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DeviceRegistration',
      if (id != null) 'id': id,
      'deviceId': deviceId,
      'userId': userId.toJson(),
      'deviceToken': deviceToken,
      if (deviceName != null) 'deviceName': deviceName,
      'registeredAt': registeredAt.toJson(),
      if (lastSeenAt != null) 'lastSeenAt': lastSeenAt?.toJson(),
    };
  }

  static DeviceRegistrationInclude include() {
    return DeviceRegistrationInclude._();
  }

  static DeviceRegistrationIncludeList includeList({
    _is.WhereExpressionBuilder<DeviceRegistrationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DeviceRegistrationTable>? orderBy,
    _is.OrderByListBuilder<DeviceRegistrationTable>? orderByList,
    DeviceRegistrationInclude? include,
  }) {
    return DeviceRegistrationIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DeviceRegistration.t),
      orderByList: orderByList?.call(DeviceRegistration.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DeviceRegistrationImpl extends DeviceRegistration {
  _DeviceRegistrationImpl({
    int? id,
    required String deviceId,
    required _is.UuidValue userId,
    required String deviceToken,
    String? deviceName,
    required DateTime registeredAt,
    DateTime? lastSeenAt,
  }) : super._(
         id: id,
         deviceId: deviceId,
         userId: userId,
         deviceToken: deviceToken,
         deviceName: deviceName,
         registeredAt: registeredAt,
         lastSeenAt: lastSeenAt,
       );

  /// Returns a shallow copy of this [DeviceRegistration]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DeviceRegistration copyWith({
    Object? id = _Undefined,
    String? deviceId,
    _is.UuidValue? userId,
    String? deviceToken,
    Object? deviceName = _Undefined,
    DateTime? registeredAt,
    Object? lastSeenAt = _Undefined,
  }) {
    return DeviceRegistration(
      id: id is int? ? id : this.id,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      deviceToken: deviceToken ?? this.deviceToken,
      deviceName: deviceName is String? ? deviceName : this.deviceName,
      registeredAt: registeredAt ?? this.registeredAt,
      lastSeenAt: lastSeenAt is DateTime? ? lastSeenAt : this.lastSeenAt,
    );
  }
}

class DeviceRegistrationUpdateTable
    extends _is.UpdateTable<DeviceRegistrationTable> {
  DeviceRegistrationUpdateTable(super.table);

  _is.ColumnValue<String, String> deviceId(String value) => _is.ColumnValue(
    table.deviceId,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> userId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.userId,
        value,
      );

  _is.ColumnValue<String, String> deviceToken(String value) => _is.ColumnValue(
    table.deviceToken,
    value,
  );

  _is.ColumnValue<String, String> deviceName(String? value) => _is.ColumnValue(
    table.deviceName,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> registeredAt(DateTime value) =>
      _is.ColumnValue(
        table.registeredAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> lastSeenAt(DateTime? value) =>
      _is.ColumnValue(
        table.lastSeenAt,
        value,
      );
}

class DeviceRegistrationTable extends _is.Table<int?> {
  DeviceRegistrationTable({super.tableRelation})
    : super(tableName: 'device_registrations') {
    updateTable = DeviceRegistrationUpdateTable(this);
    deviceId = _is.ColumnString(
      'deviceId',
      this,
    );
    userId = _is.ColumnUuid(
      'userId',
      this,
    );
    deviceToken = _is.ColumnString(
      'deviceToken',
      this,
    );
    deviceName = _is.ColumnString(
      'deviceName',
      this,
    );
    registeredAt = _is.ColumnDateTime(
      'registeredAt',
      this,
    );
    lastSeenAt = _is.ColumnDateTime(
      'lastSeenAt',
      this,
    );
  }

  late final DeviceRegistrationUpdateTable updateTable;

  late final _is.ColumnString deviceId;

  late final _is.ColumnUuid userId;

  late final _is.ColumnString deviceToken;

  late final _is.ColumnString deviceName;

  late final _is.ColumnDateTime registeredAt;

  late final _is.ColumnDateTime lastSeenAt;

  @override
  List<_is.Column> get columns => [
    id,
    deviceId,
    userId,
    deviceToken,
    deviceName,
    registeredAt,
    lastSeenAt,
  ];
}

class DeviceRegistrationInclude extends _is.IncludeObject {
  DeviceRegistrationInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => DeviceRegistration.t;
}

class DeviceRegistrationIncludeList extends _is.IncludeList {
  DeviceRegistrationIncludeList._({
    _is.WhereExpressionBuilder<DeviceRegistrationTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DeviceRegistration.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => DeviceRegistration.t;
}

class DeviceRegistrationRepository {
  const DeviceRegistrationRepository._();

  /// Returns a list of [DeviceRegistration]s matching the given query parameters.
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
  Future<List<DeviceRegistration>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DeviceRegistrationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DeviceRegistrationTable>? orderBy,
    _is.OrderByListBuilder<DeviceRegistrationTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DeviceRegistration>(
      where: where?.call(DeviceRegistration.t),
      orderBy: orderBy?.call(DeviceRegistration.t),
      orderByList: orderByList?.call(DeviceRegistration.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DeviceRegistration] matching the given query parameters.
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
  Future<DeviceRegistration?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DeviceRegistrationTable>? where,
    int? offset,
    _is.OrderByBuilder<DeviceRegistrationTable>? orderBy,
    _is.OrderByListBuilder<DeviceRegistrationTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DeviceRegistration>(
      where: where?.call(DeviceRegistration.t),
      orderBy: orderBy?.call(DeviceRegistration.t),
      orderByList: orderByList?.call(DeviceRegistration.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DeviceRegistration] by its [id] or null if no such row exists.
  Future<DeviceRegistration?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DeviceRegistration>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DeviceRegistration]s in the list and returns the inserted rows.
  ///
  /// The returned [DeviceRegistration]s will have their `id` fields set.
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
  Future<List<DeviceRegistration>> insert(
    _is.DatabaseSession session,
    List<DeviceRegistration> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<DeviceRegistration>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [DeviceRegistration] and returns the inserted row.
  ///
  /// The returned [DeviceRegistration] will have its `id` field set.
  Future<DeviceRegistration> insertRow(
    _is.DatabaseSession session,
    DeviceRegistration row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<DeviceRegistration>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [DeviceRegistration]s in the list and returns the resulting rows.
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
  /// The returned [DeviceRegistration]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DeviceRegistration>> upsert(
    _is.DatabaseSession session,
    List<DeviceRegistration> rows, {
    required _is.ColumnSelections<DeviceRegistrationTable> conflictColumns,
    _is.ColumnSelections<DeviceRegistrationTable>? updateColumns,
    _is.WhereExpressionBuilder<DeviceRegistrationTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<DeviceRegistration>(
      rows,
      conflictColumns: conflictColumns(DeviceRegistration.t),
      updateColumns: updateColumns?.call(DeviceRegistration.t),
      updateWhere: updateWhere?.call(DeviceRegistration.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [DeviceRegistration] and returns the resulting row.
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
  /// The returned [DeviceRegistration] will have its `id` field set.
  Future<DeviceRegistration?> upsertRow(
    _is.DatabaseSession session,
    DeviceRegistration row, {
    required _is.ColumnSelections<DeviceRegistrationTable> conflictColumns,
    _is.ColumnSelections<DeviceRegistrationTable>? updateColumns,
    _is.WhereExpressionBuilder<DeviceRegistrationTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<DeviceRegistration>(
      row,
      conflictColumns: conflictColumns(DeviceRegistration.t),
      updateColumns: updateColumns?.call(DeviceRegistration.t),
      updateWhere: updateWhere?.call(DeviceRegistration.t),
      transaction: transaction,
    );
  }

  /// Updates all [DeviceRegistration]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DeviceRegistration>> update(
    _is.DatabaseSession session,
    List<DeviceRegistration> rows, {
    _is.ColumnSelections<DeviceRegistrationTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<DeviceRegistration>(
      rows,
      columns: columns?.call(DeviceRegistration.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [DeviceRegistration]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DeviceRegistration> updateRow(
    _is.DatabaseSession session,
    DeviceRegistration row, {
    _is.ColumnSelections<DeviceRegistrationTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<DeviceRegistration>(
      row,
      columns: columns?.call(DeviceRegistration.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DeviceRegistration] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DeviceRegistration?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<DeviceRegistrationUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<DeviceRegistration>(
      id,
      columnValues: columnValues(DeviceRegistration.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DeviceRegistration]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DeviceRegistration>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<DeviceRegistrationUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<DeviceRegistrationTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DeviceRegistrationTable>? orderBy,
    _is.OrderByListBuilder<DeviceRegistrationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<DeviceRegistration>(
      columnValues: columnValues(DeviceRegistration.t.updateTable),
      where: where(DeviceRegistration.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DeviceRegistration.t),
      orderByList: orderByList?.call(DeviceRegistration.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [DeviceRegistration]s in the list and returns the deleted rows.
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
  Future<List<DeviceRegistration>> delete(
    _is.DatabaseSession session,
    List<DeviceRegistration> rows, {
    _is.OrderByBuilder<DeviceRegistrationTable>? orderBy,
    _is.OrderByListBuilder<DeviceRegistrationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<DeviceRegistration>(
      rows,
      orderBy: orderBy?.call(DeviceRegistration.t),
      orderByList: orderByList?.call(DeviceRegistration.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [DeviceRegistration].
  Future<DeviceRegistration> deleteRow(
    _is.DatabaseSession session,
    DeviceRegistration row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DeviceRegistration>(
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
  Future<List<DeviceRegistration>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DeviceRegistrationTable> where,
    _is.OrderByBuilder<DeviceRegistrationTable>? orderBy,
    _is.OrderByListBuilder<DeviceRegistrationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<DeviceRegistration>(
      where: where(DeviceRegistration.t),
      orderBy: orderBy?.call(DeviceRegistration.t),
      orderByList: orderByList?.call(DeviceRegistration.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DeviceRegistrationTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<DeviceRegistration>(
      where: where?.call(DeviceRegistration.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DeviceRegistration] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DeviceRegistrationTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DeviceRegistration>(
      where: where(DeviceRegistration.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
