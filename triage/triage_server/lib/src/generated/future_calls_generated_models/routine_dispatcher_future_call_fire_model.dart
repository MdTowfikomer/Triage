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

abstract class RoutineDispatcherFutureCallFireModel
    implements _is.SerializableModel, _is.ProtocolSerialization {
  RoutineDispatcherFutureCallFireModel._({required this.routineId});

  factory RoutineDispatcherFutureCallFireModel({required String routineId}) =
      _RoutineDispatcherFutureCallFireModelImpl;

  factory RoutineDispatcherFutureCallFireModel.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return RoutineDispatcherFutureCallFireModel(
      routineId: jsonSerialization['routineId'] as String,
    );
  }

  String routineId;

  /// Returns a shallow copy of this [RoutineDispatcherFutureCallFireModel]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  RoutineDispatcherFutureCallFireModel copyWith({String? routineId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RoutineDispatcherFutureCallFireModel',
      'routineId': routineId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _RoutineDispatcherFutureCallFireModelImpl
    extends RoutineDispatcherFutureCallFireModel {
  _RoutineDispatcherFutureCallFireModelImpl({required String routineId})
    : super._(routineId: routineId);

  /// Returns a shallow copy of this [RoutineDispatcherFutureCallFireModel]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  RoutineDispatcherFutureCallFireModel copyWith({String? routineId}) {
    return RoutineDispatcherFutureCallFireModel(
      routineId: routineId ?? this.routineId,
    );
  }
}
