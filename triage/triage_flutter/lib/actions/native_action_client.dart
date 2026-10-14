import 'package:flutter/services.dart';
import 'action_result.dart';

class NativeActionClient {
  static const MethodChannel _channel = MethodChannel('triage.native_actions');

  final MethodChannel channel;

  NativeActionClient({MethodChannel? channel}) : channel = channel ?? _channel;

  // --- Volume ---

  Future<ActionResult> setVolume(dynamic percent, {bool showUi = true}) async {
    return _invokeAction('setVolume', {
      'percent': percent,
      'showUi': showUi,
    }, defaultAction: 'set_volume');
  }

  Future<ActionResult> getVolume() async {
    return _invokeAction('getVolume', null, defaultAction: 'get_volume');
  }

  // --- Screen Brightness ---

  Future<ActionResult> setBrightness(dynamic percent) async {
    return _invokeAction('setBrightness', {
      'percent': percent,
    }, defaultAction: 'set_brightness');
  }

  Future<ActionResult> getBrightness() async {
    return _invokeAction(
      'getBrightness',
      null,
      defaultAction: 'get_brightness',
    );
  }

  Future<ActionResult> openWriteSettings() async {
    return _invokeAction(
      'openWriteSettings',
      null,
      defaultAction: 'open_write_settings',
    );
  }

  // --- Do Not Disturb (DND) ---

  Future<ActionResult> setDoNotDisturb(bool enabled) async {
    return _invokeAction('setDoNotDisturb', {
      'enabled': enabled,
    }, defaultAction: 'set_dnd');
  }

  Future<ActionResult> getDoNotDisturb() async {
    return _invokeAction('getDoNotDisturb', null, defaultAction: 'get_dnd');
  }

  Future<ActionResult> openNotificationPolicySettings() async {
    return _invokeAction(
      'openNotificationPolicySettings',
      null,
      defaultAction: 'open_notification_policy_settings',
    );
  }

  // --- Clock: Timers & Alarms ---

  Future<ActionResult> setTimer(
    int seconds, {
    String? message,
    bool skipUi = true,
  }) async {
    return _invokeAction('setTimer', {
      'seconds': seconds,
      'message': message,
      'skipUi': skipUi,
    }, defaultAction: 'set_timer');
  }

  Future<ActionResult> setAlarm(
    int hour,
    int minutes, {
    String? message,
    bool skipUi = true,
  }) async {
    return _invokeAction('setAlarm', {
      'hour': hour,
      'minutes': minutes,
      'message': message,
      'skipUi': skipUi,
    }, defaultAction: 'set_alarm');
  }

  // --- Applications ---

  Future<ActionResult> openApp(String appNameOrPackage) async {
    return _invokeAction('openApp', {
      'app': appNameOrPackage,
    }, defaultAction: 'open_app');
  }

  // --- Contacts & Communication ---

  Future<Map<String, dynamic>> searchContacts(String query) async {
    try {
      final res = await channel.invokeMethod<Map<dynamic, dynamic>>(
        'searchContacts',
        {'query': query},
      );
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
      return {'status': 'error', 'contacts': []};
    } catch (e) {
      return {'status': 'error', 'errorMessage': e.toString(), 'contacts': []};
    }
  }

  Future<Map<String, dynamic>> pickContact() async {
    try {
      final response = await channel.invokeMethod<Map<dynamic, dynamic>>(
        'pickContact',
      );
      return response == null
          ? {'status': 'unavailable'}
          : Map<String, dynamic>.from(response);
    } catch (error) {
      return {'status': 'unavailable', 'errorMessage': error.toString()};
    }
  }

  Future<ActionResult> dialContact({
    required String phoneNumber,
    String? name,
  }) async {
    return _invokeAction('dialContact', {
      'phoneNumber': phoneNumber,
      'name': name ?? phoneNumber,
    }, defaultAction: 'dial_contact');
  }

  Future<ActionResult> composeSms({
    required String phoneNumber,
    required String message,
    String? name,
  }) async {
    return _invokeAction('composeSms', {
      'phoneNumber': phoneNumber,
      'message': message,
      'name': name ?? phoneNumber,
    }, defaultAction: 'compose_sms');
  }

  Future<ActionResult> composeWhatsApp({
    required String phoneNumber,
    required String message,
    String? name,
  }) async {
    return _invokeAction('composeWhatsApp', {
      'phoneNumber': phoneNumber,
      'message': message,
      'name': name ?? phoneNumber,
    }, defaultAction: 'compose_whatsapp');
  }

  Future<ActionResult> openNavigation(String destination) async {
    return _invokeAction('openNavigation', {
      'destination': destination,
    }, defaultAction: 'open_navigation');
  }

  Future<List<Map<String, String>>> getInstalledApps() async {
    try {
      final res = await channel.invokeMethod<List<dynamic>>('getInstalledApps');
      if (res != null) {
        return res.map((item) {
          final m = Map<dynamic, dynamic>.from(item as Map);
          return {
            'packageName': m['packageName']?.toString() ?? '',
            'label': m['label']?.toString() ?? '',
          };
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // --- Media Controls ---

  Future<ActionResult> mediaControl(String command) async {
    return _invokeAction('mediaControl', {
      'command': command,
    }, defaultAction: 'media_control');
  }

  Future<ActionResult> mediaNext() => mediaControl('next');
  Future<ActionResult> mediaPrevious() => mediaControl('previous');
  Future<ActionResult> mediaPlayPause() => mediaControl('play_pause');

  // --- Exact Alarms & Routine Scheduling (Ticket 10) ---

  Future<bool> canScheduleExactAlarms() async {
    try {
      final res = await channel.invokeMethod<bool>('canScheduleExactAlarms');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<ActionResult> openExactAlarmSettings() async {
    return _invokeAction(
      'openExactAlarmSettings',
      null,
      defaultAction: 'open_exact_alarm_settings',
    );
  }

  Future<ActionResult> scheduleExactAlarm(
    String occurrenceId,
    int epochMs, {
    String name = 'Scheduled Routine',
  }) async {
    return _invokeAction('scheduleExactAlarm', {
      'occurrenceId': occurrenceId,
      'epochMs': epochMs,
      'name': name,
    }, defaultAction: 'schedule_exact_alarm');
  }

  Future<ActionResult> cancelExactAlarm(String occurrenceId) async {
    return _invokeAction('cancelExactAlarm', {
      'occurrenceId': occurrenceId,
    }, defaultAction: 'cancel_exact_alarm');
  }

  Future<void> Function(String occurrenceId, String name)? _alarmHandler;
  void Function()? _shakeHandler;
  void Function()? _backgroundShakeHandler;
  bool _methodHandlerInstalled = false;

  void _ensureMethodHandler() {
    if (_methodHandlerInstalled) return;
    _methodHandlerInstalled = true;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmTriggered') {
        final occurrenceId = call.arguments?['occurrenceId'] as String? ?? '';
        final name = call.arguments?['name'] as String? ?? '';
        if (occurrenceId.isNotEmpty && _alarmHandler != null) {
          await _alarmHandler!(occurrenceId, name);
        }
      } else if (call.method == 'onDeviceShaken') {
        _shakeHandler?.call();
      } else if (call.method == 'onBackgroundShakeLaunch') {
        _backgroundShakeHandler?.call();
      }
    });
  }

  void registerAlarmHandler(
    Future<void> Function(String occurrenceId, String name) handler,
  ) {
    _alarmHandler = handler;
    _ensureMethodHandler();

    // Check and drain any pending trigger buffered during cold start before Dart listener registered
    channel
        .invokeMethod('getPendingAlarmTrigger')
        .then((dynamic res) {
          if (res is Map) {
            final occurrenceId = res['occurrenceId'] as String? ?? '';
            final name = res['name'] as String? ?? '';
            if (occurrenceId.isNotEmpty) {
              handler(occurrenceId, name);
            }
          }
        })
        .catchError((_) {});
  }

  // --- Capabilities Check ---

  Future<Map<String, bool>> checkCapabilities() async {
    try {
      final dynamic res = await channel.invokeMethod('checkCapabilities');
      if (res is Map) {
        return {
          'canWriteSettings': res['canWriteSettings'] == true,
          'isNotificationPolicyAccessGranted':
              res['isNotificationPolicyAccessGranted'] == true,
          'canScheduleExactAlarms': res['canScheduleExactAlarms'] == true,
        };
      }
    } catch (_) {}
    return {
      'canWriteSettings': false,
      'isNotificationPolicyAccessGranted': false,
      'canScheduleExactAlarms': false,
    };
  }

  // --- Helper Dispatcher ---

  Future<ActionResult> _invokeAction(
    String method,
    Map<String, dynamic>? arguments, {
    required String defaultAction,
  }) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    try {
      final dynamic result = await channel.invokeMethod(method, arguments);

      if (result is Map) {
        return ActionResult.fromMap(result);
      }

      final latencyMs = DateTime.now().millisecondsSinceEpoch - startTime;
      return ActionResult(
        status: ActionStatus.error,
        action: defaultAction,
        executionLatencyMs: latencyMs,
        errorCode: 'INVALID_RESULT_PAYLOAD',
        errorMessage: 'Native bridge returned invalid payload.',
      );
    } on PlatformException catch (e) {
      final latencyMs = DateTime.now().millisecondsSinceEpoch - startTime;
      return ActionResult(
        status: ActionStatus.error,
        action: defaultAction,
        executionLatencyMs: latencyMs,
        errorCode: e.code,
        errorMessage: e.message,
      );
    } catch (e) {
      final latencyMs = DateTime.now().millisecondsSinceEpoch - startTime;
      return ActionResult(
        status: ActionStatus.error,
        action: defaultAction,
        executionLatencyMs: latencyMs,
        errorCode: 'UNEXPECTED_ERROR',
        errorMessage: e.toString(),
      );
    }
  }

  // --- Shake Detection & Haptic Feedback (Ticket 12) ---

  Future<bool> startShakeDetection({
    void Function()? onShaken,
    void Function()? onBackgroundShake,
  }) async {
    try {
      _shakeHandler = onShaken;
      _backgroundShakeHandler = onBackgroundShake;
      _ensureMethodHandler();
      final dynamic res = await channel.invokeMethod('startShakeDetection');
      final pending = await channel.invokeMethod<bool>(
        'getPendingBackgroundShake',
      );
      if (pending == true) _backgroundShakeHandler?.call();
      if (res is Map && res['status'] == 'success') {
        return res['active'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopShakeDetection() async {
    try {
      final dynamic res = await channel.invokeMethod('stopShakeDetection');
      return res is Map && res['status'] == 'success';
    } catch (_) {
      return false;
    }
  }

  Future<bool> setBackgroundShakeEnabled(bool enabled) async {
    try {
      return await channel.invokeMethod<bool>('setBackgroundShakeEnabled', {
            'enabled': enabled,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openTriggerAccessibilitySettings() async {
    await channel.invokeMethod<void>('openTriggerAccessibilitySettings');
  }

  Future<void> triggerHapticFeedback({String type = 'medium'}) async {
    try {
      await channel.invokeMethod('triggerHapticFeedback', {'type': type});
    } catch (_) {}
  }
}
