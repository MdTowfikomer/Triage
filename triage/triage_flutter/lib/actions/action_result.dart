enum ActionStatus {
  success,
  handedOff,
  permissionRequired,
  unsupported,
  ambiguous,
  error;

  static ActionStatus fromString(String? value) {
    switch (value) {
      case 'success':
        return ActionStatus.success;
      case 'handed_off':
        return ActionStatus.handedOff;
      case 'permission_required':
        return ActionStatus.permissionRequired;
      case 'unsupported':
        return ActionStatus.unsupported;
      case 'ambiguous':
        return ActionStatus.ambiguous;
      case 'error':
      default:
        return ActionStatus.error;
    }
  }

  String toValue() {
    switch (this) {
      case ActionStatus.success:
        return 'success';
      case ActionStatus.handedOff:
        return 'handed_off';
      case ActionStatus.permissionRequired:
        return 'permission_required';
      case ActionStatus.unsupported:
        return 'unsupported';
      case ActionStatus.ambiguous:
        return 'ambiguous';
      case ActionStatus.error:
        return 'error';
    }
  }
}

class ActionResult {
  final ActionStatus status;
  final String action;
  final dynamic previousValue;
  final dynamic targetValue;
  final int executionLatencyMs;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, dynamic> extra;

  const ActionResult({
    required this.status,
    required this.action,
    this.previousValue,
    this.targetValue,
    required this.executionLatencyMs,
    this.errorCode,
    this.errorMessage,
    this.extra = const {},
  });

  bool get isSuccess => status == ActionStatus.success;

  factory ActionResult.fromMap(Map<dynamic, dynamic> map) {
    return ActionResult(
      status: ActionStatus.fromString(map['status'] as String?),
      action: map['action'] as String? ?? 'unknown',
      previousValue: map['previousValue'],
      targetValue: map['targetValue'],
      executionLatencyMs: (map['executionLatencyMs'] as num?)?.toInt() ?? 0,
      errorCode: map['errorCode'] as String?,
      errorMessage: map['errorMessage'] as String?,
      extra: map['extra'] != null ? Map<String, dynamic>.from(map['extra'] as Map) : const {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status.toValue(),
      'action': action,
      'previousValue': previousValue,
      'targetValue': targetValue,
      'executionLatencyMs': executionLatencyMs,
      'errorCode': errorCode,
      'errorMessage': errorMessage,
      if (extra.isNotEmpty) 'extra': extra,
    };
  }

  @override
  String toString() {
    return 'ActionResult(status: ${status.toValue()}, action: $action, previousValue: $previousValue, targetValue: $targetValue, executionLatencyMs: ${executionLatencyMs}ms, errorCode: $errorCode)';
  }
}
