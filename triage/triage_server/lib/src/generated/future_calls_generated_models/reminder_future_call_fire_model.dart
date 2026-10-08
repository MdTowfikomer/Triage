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

abstract class ReminderFutureCallFireModel
    implements _is.SerializableModel, _is.ProtocolSerialization {
  ReminderFutureCallFireModel._({required this.reminderId});

  factory ReminderFutureCallFireModel({required int reminderId}) =
      _ReminderFutureCallFireModelImpl;

  factory ReminderFutureCallFireModel.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ReminderFutureCallFireModel(
      reminderId: jsonSerialization['reminderId'] as int,
    );
  }

  int reminderId;

  /// Returns a shallow copy of this [ReminderFutureCallFireModel]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ReminderFutureCallFireModel copyWith({int? reminderId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ReminderFutureCallFireModel',
      'reminderId': reminderId,
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

class _ReminderFutureCallFireModelImpl extends ReminderFutureCallFireModel {
  _ReminderFutureCallFireModelImpl({required int reminderId})
    : super._(reminderId: reminderId);

  /// Returns a shallow copy of this [ReminderFutureCallFireModel]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ReminderFutureCallFireModel copyWith({int? reminderId}) {
    return ReminderFutureCallFireModel(
      reminderId: reminderId ?? this.reminderId,
    );
  }
}
