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

abstract class DeviceTelemetry
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  DeviceTelemetry._({
    this.id,
    required this.deviceId,
    required this.batteryLevel,
    required this.isCharging,
    required this.volumeLevel,
    required this.brightnessLevel,
    required this.dndEnabled,
    required this.updatedAt,
  });

  factory DeviceTelemetry({
    int? id,
    required String deviceId,
    required int batteryLevel,
    required bool isCharging,
    required double volumeLevel,
    required double brightnessLevel,
    required bool dndEnabled,
    required DateTime updatedAt,
  }) = _DeviceTelemetryImpl;

  factory DeviceTelemetry.fromJson(Map<String, dynamic> jsonSerialization) {
    return DeviceTelemetry(
      id: jsonSerialization['id'] as int?,
      deviceId: jsonSerialization['deviceId'] as String,
      batteryLevel: jsonSerialization['batteryLevel'] as int,
      isCharging: _is.BoolJsonExtension.fromJson(
        jsonSerialization['isCharging'],
      ),
      volumeLevel: (jsonSerialization['volumeLevel'] as num).toDouble(),
      brightnessLevel: (jsonSerialization['brightnessLevel'] as num).toDouble(),
      dndEnabled: _is.BoolJsonExtension.fromJson(
        jsonSerialization['dndEnabled'],
      ),
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = DeviceTelemetryTable();

  static const db = DeviceTelemetryRepository._();

  @override
  int? id;

  String deviceId;

  int batteryLevel;

  bool isCharging;

  double volumeLevel;

  double brightnessLevel;

  bool dndEnabled;

  DateTime updatedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [DeviceTelemetry]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DeviceTelemetry copyWith({
    int? id,
    String? deviceId,
    int? batteryLevel,
    bool? isCharging,
    double? volumeLevel,
    double? brightnessLevel,
    bool? dndEnabled,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DeviceTelemetry',
      if (id != null) 'id': id,
      'deviceId': deviceId,
      'batteryLevel': batteryLevel,
      'isCharging': isCharging,
      'volumeLevel': volumeLevel,
      'brightnessLevel': brightnessLevel,
      'dndEnabled': dndEnabled,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DeviceTelemetry',
      if (id != null) 'id': id,
      'deviceId': deviceId,
      'batteryLevel': batteryLevel,
      'isCharging': isCharging,
      'volumeLevel': volumeLevel,
      'brightnessLevel': brightnessLevel,
      'dndEnabled': dndEnabled,
      'updatedAt': updatedAt.toJson(),
    };
  }

  static DeviceTelemetryInclude include() {
    return DeviceTelemetryInclude._();
  }

  static DeviceTelemetryIncludeList includeList({
    _is.WhereExpressionBuilder<DeviceTelemetryTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DeviceTelemetryTable>? orderBy,
    _is.OrderByListBuilder<DeviceTelemetryTable>? orderByList,
    DeviceTelemetryInclude? include,
  }) {
    return DeviceTelemetryIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DeviceTelemetry.t),
      orderByList: orderByList?.call(DeviceTelemetry.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DeviceTelemetryImpl extends DeviceTelemetry {
  _DeviceTelemetryImpl({
    int? id,
    required String deviceId,
    required int batteryLevel,
    required bool isCharging,
    required double volumeLevel,
    required double brightnessLevel,
    required bool dndEnabled,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         deviceId: deviceId,
         batteryLevel: batteryLevel,
         isCharging: isCharging,
         volumeLevel: volumeLevel,
         brightnessLevel: brightnessLevel,
         dndEnabled: dndEnabled,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [DeviceTelemetry]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DeviceTelemetry copyWith({
    Object? id = _Undefined,
    String? deviceId,
    int? batteryLevel,
    bool? isCharging,
    double? volumeLevel,
    double? brightnessLevel,
    bool? dndEnabled,
    DateTime? updatedAt,
  }) {
    return DeviceTelemetry(
      id: id is int? ? id : this.id,
      deviceId: deviceId ?? this.deviceId,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      volumeLevel: volumeLevel ?? this.volumeLevel,
      brightnessLevel: brightnessLevel ?? this.brightnessLevel,
      dndEnabled: dndEnabled ?? this.dndEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DeviceTelemetryUpdateTable extends _is.UpdateTable<DeviceTelemetryTable> {
  DeviceTelemetryUpdateTable(super.table);

  _is.ColumnValue<String, String> deviceId(String value) => _is.ColumnValue(
    table.deviceId,
    value,
  );

  _is.ColumnValue<int, int> batteryLevel(int value) => _is.ColumnValue(
    table.batteryLevel,
    value,
  );

  _is.ColumnValue<bool, bool> isCharging(bool value) => _is.ColumnValue(
    table.isCharging,
    value,
  );

  _is.ColumnValue<double, double> volumeLevel(double value) => _is.ColumnValue(
    table.volumeLevel,
    value,
  );

  _is.ColumnValue<double, double> brightnessLevel(double value) =>
      _is.ColumnValue(
        table.brightnessLevel,
        value,
      );

  _is.ColumnValue<bool, bool> dndEnabled(bool value) => _is.ColumnValue(
    table.dndEnabled,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );
}

class DeviceTelemetryTable extends _is.Table<int?> {
  DeviceTelemetryTable({super.tableRelation})
    : super(tableName: 'device_telemetry') {
    updateTable = DeviceTelemetryUpdateTable(this);
    deviceId = _is.ColumnString(
      'deviceId',
      this,
    );
    batteryLevel = _is.ColumnInt(
      'batteryLevel',
      this,
    );
    isCharging = _is.ColumnBool(
      'isCharging',
      this,
    );
    volumeLevel = _is.ColumnDouble(
      'volumeLevel',
      this,
    );
    brightnessLevel = _is.ColumnDouble(
      'brightnessLevel',
      this,
    );
    dndEnabled = _is.ColumnBool(
      'dndEnabled',
      this,
    );
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
    );
  }

  late final DeviceTelemetryUpdateTable updateTable;

  late final _is.ColumnString deviceId;

  late final _is.ColumnInt batteryLevel;

  late final _is.ColumnBool isCharging;

  late final _is.ColumnDouble volumeLevel;

  late final _is.ColumnDouble brightnessLevel;

  late final _is.ColumnBool dndEnabled;

  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    deviceId,
    batteryLevel,
    isCharging,
    volumeLevel,
    brightnessLevel,
    dndEnabled,
    updatedAt,
  ];
}

class DeviceTelemetryInclude extends _is.IncludeObject {
  DeviceTelemetryInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => DeviceTelemetry.t;
}

class DeviceTelemetryIncludeList extends _is.IncludeList {
  DeviceTelemetryIncludeList._({
    _is.WhereExpressionBuilder<DeviceTelemetryTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DeviceTelemetry.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => DeviceTelemetry.t;
}

class DeviceTelemetryRepository {
  const DeviceTelemetryRepository._();

  /// Returns a list of [DeviceTelemetry]s matching the given query parameters.
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
  Future<List<DeviceTelemetry>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DeviceTelemetryTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DeviceTelemetryTable>? orderBy,
    _is.OrderByListBuilder<DeviceTelemetryTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DeviceTelemetry>(
      where: where?.call(DeviceTelemetry.t),
      orderBy: orderBy?.call(DeviceTelemetry.t),
      orderByList: orderByList?.call(DeviceTelemetry.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DeviceTelemetry] matching the given query parameters.
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
  Future<DeviceTelemetry?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DeviceTelemetryTable>? where,
    int? offset,
    _is.OrderByBuilder<DeviceTelemetryTable>? orderBy,
    _is.OrderByListBuilder<DeviceTelemetryTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DeviceTelemetry>(
      where: where?.call(DeviceTelemetry.t),
      orderBy: orderBy?.call(DeviceTelemetry.t),
      orderByList: orderByList?.call(DeviceTelemetry.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DeviceTelemetry] by its [id] or null if no such row exists.
  Future<DeviceTelemetry?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DeviceTelemetry>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DeviceTelemetry]s in the list and returns the inserted rows.
  ///
  /// The returned [DeviceTelemetry]s will have their `id` fields set.
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
  Future<List<DeviceTelemetry>> insert(
    _is.DatabaseSession session,
    List<DeviceTelemetry> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<DeviceTelemetry>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [DeviceTelemetry] and returns the inserted row.
  ///
  /// The returned [DeviceTelemetry] will have its `id` field set.
  Future<DeviceTelemetry> insertRow(
    _is.DatabaseSession session,
    DeviceTelemetry row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<DeviceTelemetry>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [DeviceTelemetry]s in the list and returns the resulting rows.
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
  /// The returned [DeviceTelemetry]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DeviceTelemetry>> upsert(
    _is.DatabaseSession session,
    List<DeviceTelemetry> rows, {
    required _is.ColumnSelections<DeviceTelemetryTable> conflictColumns,
    _is.ColumnSelections<DeviceTelemetryTable>? updateColumns,
    _is.WhereExpressionBuilder<DeviceTelemetryTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<DeviceTelemetry>(
      rows,
      conflictColumns: conflictColumns(DeviceTelemetry.t),
      updateColumns: updateColumns?.call(DeviceTelemetry.t),
      updateWhere: updateWhere?.call(DeviceTelemetry.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [DeviceTelemetry] and returns the resulting row.
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
  /// The returned [DeviceTelemetry] will have its `id` field set.
  Future<DeviceTelemetry?> upsertRow(
    _is.DatabaseSession session,
    DeviceTelemetry row, {
    required _is.ColumnSelections<DeviceTelemetryTable> conflictColumns,
    _is.ColumnSelections<DeviceTelemetryTable>? updateColumns,
    _is.WhereExpressionBuilder<DeviceTelemetryTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<DeviceTelemetry>(
      row,
      conflictColumns: conflictColumns(DeviceTelemetry.t),
      updateColumns: updateColumns?.call(DeviceTelemetry.t),
      updateWhere: updateWhere?.call(DeviceTelemetry.t),
      transaction: transaction,
    );
  }

  /// Updates all [DeviceTelemetry]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DeviceTelemetry>> update(
    _is.DatabaseSession session,
    List<DeviceTelemetry> rows, {
    _is.ColumnSelections<DeviceTelemetryTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<DeviceTelemetry>(
      rows,
      columns: columns?.call(DeviceTelemetry.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [DeviceTelemetry]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DeviceTelemetry> updateRow(
    _is.DatabaseSession session,
    DeviceTelemetry row, {
    _is.ColumnSelections<DeviceTelemetryTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<DeviceTelemetry>(
      row,
      columns: columns?.call(DeviceTelemetry.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DeviceTelemetry] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DeviceTelemetry?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<DeviceTelemetryUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<DeviceTelemetry>(
      id,
      columnValues: columnValues(DeviceTelemetry.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DeviceTelemetry]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DeviceTelemetry>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<DeviceTelemetryUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<DeviceTelemetryTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DeviceTelemetryTable>? orderBy,
    _is.OrderByListBuilder<DeviceTelemetryTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<DeviceTelemetry>(
      columnValues: columnValues(DeviceTelemetry.t.updateTable),
      where: where(DeviceTelemetry.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DeviceTelemetry.t),
      orderByList: orderByList?.call(DeviceTelemetry.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [DeviceTelemetry]s in the list and returns the deleted rows.
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
  Future<List<DeviceTelemetry>> delete(
    _is.DatabaseSession session,
    List<DeviceTelemetry> rows, {
    _is.OrderByBuilder<DeviceTelemetryTable>? orderBy,
    _is.OrderByListBuilder<DeviceTelemetryTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<DeviceTelemetry>(
      rows,
      orderBy: orderBy?.call(DeviceTelemetry.t),
      orderByList: orderByList?.call(DeviceTelemetry.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [DeviceTelemetry].
  Future<DeviceTelemetry> deleteRow(
    _is.DatabaseSession session,
    DeviceTelemetry row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DeviceTelemetry>(
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
  Future<List<DeviceTelemetry>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DeviceTelemetryTable> where,
    _is.OrderByBuilder<DeviceTelemetryTable>? orderBy,
    _is.OrderByListBuilder<DeviceTelemetryTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<DeviceTelemetry>(
      where: where(DeviceTelemetry.t),
      orderBy: orderBy?.call(DeviceTelemetry.t),
      orderByList: orderByList?.call(DeviceTelemetry.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DeviceTelemetryTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<DeviceTelemetry>(
      where: where?.call(DeviceTelemetry.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DeviceTelemetry] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DeviceTelemetryTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DeviceTelemetry>(
      where: where(DeviceTelemetry.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
