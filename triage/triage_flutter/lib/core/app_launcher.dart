import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:triage_decision/action_funnel.dart';

abstract interface class AppLauncher {
  Future<bool> launch(String appName);
}

class AndroidAppLauncher implements AppLauncher {
  const AndroidAppLauncher();
  static const _channel = MethodChannel('triage.apps');
  @override
  Future<bool> launch(String appName) async {
    if (!supportedApps.contains(appName) ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    return await _channel.invokeMethod<bool>('launch', {'appName': appName}) ??
        false;
  }
}
