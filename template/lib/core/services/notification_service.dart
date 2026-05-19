import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:__APP_PACKAGE__/core/utils/app_logger.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationTapStreamProvider = StreamProvider<String?>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.onNotificationTap;
});

class NotificationService {
  static const _log = AppLogger('NotificationService');
  static const _dailyNotificationId = 1001;

  // SharedPreferences keys used by the timezone rescheduler.
  static const kLastKnownTimezone = 'last_known_timezone';
  static const kNotificationHour = 'notification_hour';
  static const kNotificationMinute = 'notification_minute';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  final StreamController<String?> _onNotificationTap =
      StreamController.broadcast();
  Stream<String?> get onNotificationTap => _onNotificationTap.stream;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    await refreshTimezone();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      ),
    );

    await _notificationsPlugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _log.info('Notification tapped: ${response.payload}');
        _onNotificationTap.add(response.payload);
      },
    );

    _isInitialized = true;
  }

  Future<String?> refreshTimezone() async {
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      _log.info('Timezone set to ${tzInfo.identifier}');
      return tzInfo.identifier;
    } catch (e) {
      _log.warning('Timezone refresh failed: $e');
      tz.setLocalLocation(tz.UTC);
      return null;
    }
  }

  Future<void> scheduleDailyNotification({
    required TimeOfDay time,
    String title = 'Reminder',
    String body = 'Your daily reminder is ready.',
    String payload = 'daily_reminder',
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notificationsPlugin.cancel(id: _dailyNotificationId);

      Future<void> schedule(AndroidScheduleMode mode) =>
          _notificationsPlugin.zonedSchedule(
            id: _dailyNotificationId,
            title: title,
            body: body,
            scheduledDate: scheduledDate,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'daily_reminder_channel',
                'Daily reminders',
                channelDescription: 'Recurring reminders for your app',
                importance: Importance.max,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: mode,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: payload,
          );

      try {
        await schedule(AndroidScheduleMode.exactAllowWhileIdle);
      } on PlatformException catch (e) {
        if (e.code == 'exact_alarms_not_permitted') {
          _log.warning('Exact alarms not permitted; falling back to inexact');
          await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
        } else {
          rethrow;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kNotificationHour, time.hour);
      await prefs.setInt(kNotificationMinute, time.minute);
      _log.info('Scheduled daily notification for $scheduledDate');
    } catch (e, st) {
      _log.error('Failed to schedule notification', error: e, stackTrace: st);
    }
  }

  Future<void> rescheduleIfTimezoneChanged(SharedPreferences prefs) async {
    tz.initializeTimeZones();

    if (!_isInitialized) {
      await _notificationsPlugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      _isInitialized = true;
    }

    String currentTz;
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      currentTz = tzInfo.identifier;
    } catch (e) {
      _log.warning('Could not read device timezone: $e');
      return;
    }

    tz.setLocalLocation(tz.getLocation(currentTz));

    final cachedTz = prefs.getString(kLastKnownTimezone);
    if (currentTz == cachedTz) return;

    await prefs.setString(kLastKnownTimezone, currentTz);

    final hour = prefs.getInt(kNotificationHour);
    final minute = prefs.getInt(kNotificationMinute);
    if (hour == null || minute == null) return;

    await scheduleDailyNotification(
      time: TimeOfDay(hour: hour, minute: minute),
    );
  }

  Future<void> cancelDailyNotification() async {
    await _notificationsPlugin.cancel(id: _dailyNotificationId);
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<bool?> requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestExactAlarmsPermission();
      return android?.requestNotificationsPermission();
    }

    if (Platform.isIOS) {
      final ios = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return ios?.requestPermissions(alert: true, badge: true, sound: true);
    }

    return false;
  }
}
