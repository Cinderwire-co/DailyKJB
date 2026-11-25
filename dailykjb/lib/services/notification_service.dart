import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

/// What a reminder says on a given day.
typedef ReminderText = ({String title, String body});

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool get _isSupported => Platform.isIOS || Platform.isAndroid;
  bool _ready = false;

  // Ids: 100+ the daily reminder for each of the next days, 200+ the evening
  // nudge, 300 a note from the Screen Time shield. Old builds used 0 and 1.
  static const _days = 14;
  static const _dailyBase = 100;
  static const _eveningBase = 200;

  Future<void> initialize() async {
    if (!_isSupported || _ready) return;

    tzdata.initializeTimeZones();
    await _configureLocalTimeZone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    // Permission is asked for during setup, not the moment the app opens
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    _ready = true;
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Failed to get timezone: $e');
      tz.setLocalLocation(tz.getLocation('America/Chicago'));
    }
  }

  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: true);
      return result ?? false;
    } else if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final result = await androidPlugin?.requestNotificationsPermission();
      return result ?? false;
    }
    return false;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_reading',
      'Daily Reading Reminder',
      channelDescription: 'Reminds you to complete your daily Bible reading',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    ),
  );

  static const _eveningDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'missed_reading',
      'Evening Reminder',
      channelDescription:
          'A gentle reminder in the evening if you haven\'t read',
      importance: Importance.defaultImportance,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  /// Reminders for the next two weeks, each with its own words: one at the
  /// reader's time, and one in the evening. Today's are left out once today's
  /// reading is done. Called whenever the app opens or a reading is finished,
  /// so the days roll forward.
  Future<void> scheduleReminders({
    required int hour,
    required int minute,
    required bool readToday,
    required ReminderText Function(int dayOffset) text,
    required ReminderText evening,
  }) async {
    if (!_isSupported) return;
    await initialize();
    await cancelAllNotifications();

    final now = tz.TZDateTime.now(tz.local);
    for (var d = 0; d < _days; d++) {
      if (d == 0 && readToday) continue;
      final day = tz.TZDateTime(tz.local, now.year, now.month, now.day + d);
      final at = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        hour,
        minute,
      );
      if (at.isAfter(now)) {
        final t = text(d);
        await _schedule(_dailyBase + d, t.title, t.body, at, _details);
      }
      // The evening nudge, if the reminder isn't itself that late
      final eve = tz.TZDateTime(tz.local, day.year, day.month, day.day, 20);
      if (hour < 19 && eve.isAfter(now)) {
        await _schedule(
          _eveningBase + d,
          evening.title,
          evening.body,
          eve,
          _eveningDetails,
        );
      }
    }
  }

  Future<void> _schedule(
    int id,
    String title,
    String body,
    tz.TZDateTime at,
    NotificationDetails details,
  ) async {
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        at,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Could not schedule reminder $id: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    if (!_isSupported) return;
    await _notifications.cancelAll();
  }
}
