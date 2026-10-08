import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

abstract interface class ReminderScheduler {
  Future<void> initialize();
  Future<void> schedule(int id, String title, DateTime triggerAt);
  Future<void> cancel(int id);
}

class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }
    tz_data.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      web: WebInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  @override
  Future<void> schedule(int id, String title, DateTime triggerAt) async {
    if (kIsWeb) return; // Web Notifications do not support scheduled delivery.
    await initialize();
    if (!triggerAt.isAfter(DateTime.now().toUtc())) {
      await cancel(id);
      return;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (await android?.areNotificationsEnabled() == false) {
      await android?.requestNotificationsPermission();
    }
    var exactAllowed = await android?.canScheduleExactNotifications();
    if (exactAllowed == false) {
      await android?.requestExactAlarmsPermission();
      exactAllowed = await android?.canScheduleExactNotifications();
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, sound: true);
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: 'Your Triage reminder is due.',
      scheduledDate: tz.TZDateTime.from(triggerAt.toUtc(), tz.local),
      androidScheduleMode: exactAllowed == false
          ? AndroidScheduleMode.inexactAllowWhileIdle
          : AndroidScheduleMode.exactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'triage_reminders',
          'Reminders',
          channelDescription: 'Local reminders saved in Triage',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'inbox:$id',
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id: id);
  }
}

class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();
  @override
  Future<void> initialize() async {}
  @override
  Future<void> schedule(int id, String title, DateTime triggerAt) async {}
  @override
  Future<void> cancel(int id) async {}
}
