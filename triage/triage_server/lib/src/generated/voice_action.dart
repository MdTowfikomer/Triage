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
import 'package:triage_server/src/generated/protocol.dart' as _ishkju68;

abstract class VoiceActionResult
    implements _is.SerializableModel, _is.ProtocolSerialization {
  VoiceActionResult._({
    required this.actionType,
    required this.tool,
    this.appName,
    required this.title,
    this.body,
    required this.category,
    this.dateText,
    required this.priority,
    required this.confidence,
    required this.latencyMs,
    this.reviewReason,
    String? recurring,
    this.tags,
    String? routingSource,
  }) : recurring = recurring ?? 'none',
       routingSource = routingSource ?? 'deterministic';

  factory VoiceActionResult({
    required String actionType,
    required String tool,
    String? appName,
    required String title,
    String? body,
    required String category,
    String? dateText,
    required String priority,
    required double confidence,
    required int latencyMs,
    String? reviewReason,
    String? recurring,
    List<String>? tags,
    String? routingSource,
  }) = _VoiceActionResultImpl;

  factory VoiceActionResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return VoiceActionResult(
      actionType: jsonSerialization['actionType'] as String,
      tool: jsonSerialization['tool'] as String,
      appName: jsonSerialization['appName'] as String?,
      title: jsonSerialization['title'] as String,
      body: jsonSerialization['body'] as String?,
      category: jsonSerialization['category'] as String,
      dateText: jsonSerialization['dateText'] as String?,
      priority: jsonSerialization['priority'] as String,
      confidence: (jsonSerialization['confidence'] as num).toDouble(),
      latencyMs: jsonSerialization['latencyMs'] as int,
      reviewReason: jsonSerialization['reviewReason'] as String?,
      recurring: jsonSerialization['recurring'] as String?,
      tags: jsonSerialization['tags'] == null
          ? null
          : _ishkju68.Protocol().deserialize<List<String>>(
              jsonSerialization['tags'],
            ),
      routingSource: jsonSerialization['routingSource'] as String?,
    );
  }

  String actionType;

  String tool;

  String? appName;

  String title;

  String? body;

  String category;

  String? dateText;

  String priority;

  double confidence;

  int latencyMs;

  String? reviewReason;

  String recurring;

  List<String>? tags;

  String routingSource;

  /// Returns a shallow copy of this [VoiceActionResult]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  VoiceActionResult copyWith({
    String? actionType,
    String? tool,
    String? appName,
    String? title,
    String? body,
    String? category,
    String? dateText,
    String? priority,
    double? confidence,
    int? latencyMs,
    String? reviewReason,
    String? recurring,
    List<String>? tags,
    String? routingSource,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'VoiceActionResult',
      'actionType': actionType,
      'tool': tool,
      if (appName != null) 'appName': appName,
      'title': title,
      if (body != null) 'body': body,
      'category': category,
      if (dateText != null) 'dateText': dateText,
      'priority': priority,
      'confidence': confidence,
      'latencyMs': latencyMs,
      if (reviewReason != null) 'reviewReason': reviewReason,
      'recurring': recurring,
      if (tags != null) 'tags': tags?.toJson(),
      'routingSource': routingSource,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'VoiceActionResult',
      'actionType': actionType,
      'tool': tool,
      if (appName != null) 'appName': appName,
      'title': title,
      if (body != null) 'body': body,
      'category': category,
      if (dateText != null) 'dateText': dateText,
      'priority': priority,
      'confidence': confidence,
      'latencyMs': latencyMs,
      if (reviewReason != null) 'reviewReason': reviewReason,
      'recurring': recurring,
      if (tags != null) 'tags': tags?.toJson(),
      'routingSource': routingSource,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _VoiceActionResultImpl extends VoiceActionResult {
  _VoiceActionResultImpl({
    required String actionType,
    required String tool,
    String? appName,
    required String title,
    String? body,
    required String category,
    String? dateText,
    required String priority,
    required double confidence,
    required int latencyMs,
    String? reviewReason,
    String? recurring,
    List<String>? tags,
    String? routingSource,
  }) : super._(
         actionType: actionType,
         tool: tool,
         appName: appName,
         title: title,
         body: body,
         category: category,
         dateText: dateText,
         priority: priority,
         confidence: confidence,
         latencyMs: latencyMs,
         reviewReason: reviewReason,
         recurring: recurring,
         tags: tags,
         routingSource: routingSource,
       );

  /// Returns a shallow copy of this [VoiceActionResult]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  VoiceActionResult copyWith({
    String? actionType,
    String? tool,
    Object? appName = _Undefined,
    String? title,
    Object? body = _Undefined,
    String? category,
    Object? dateText = _Undefined,
    String? priority,
    double? confidence,
    int? latencyMs,
    Object? reviewReason = _Undefined,
    String? recurring,
    Object? tags = _Undefined,
    String? routingSource,
  }) {
    return VoiceActionResult(
      actionType: actionType ?? this.actionType,
      tool: tool ?? this.tool,
      appName: appName is String? ? appName : this.appName,
      title: title ?? this.title,
      body: body is String? ? body : this.body,
      category: category ?? this.category,
      dateText: dateText is String? ? dateText : this.dateText,
      priority: priority ?? this.priority,
      confidence: confidence ?? this.confidence,
      latencyMs: latencyMs ?? this.latencyMs,
      reviewReason: reviewReason is String? ? reviewReason : this.reviewReason,
      recurring: recurring ?? this.recurring,
      tags: tags is List<String>? ? tags : this.tags?.map((e0) => e0).toList(),
      routingSource: routingSource ?? this.routingSource,
    );
  }
}
