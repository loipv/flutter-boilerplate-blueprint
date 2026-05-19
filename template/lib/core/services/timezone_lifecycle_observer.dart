import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:__APP_PACKAGE__/core/services/notification_service.dart';
import 'package:__APP_PACKAGE__/core/utils/app_logger.dart';

class TimezoneLifecycleObserver extends WidgetsBindingObserver {
  TimezoneLifecycleObserver({
    required NotificationService notificationService,
    required Future<SharedPreferences> Function() getPrefs,
  }) : _service = notificationService,
       _getPrefs = getPrefs;

  static const _log = AppLogger('TimezoneLifecycleObserver');

  final NotificationService _service;
  final Future<SharedPreferences> Function() _getPrefs;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncTimezone();
    }
  }

  Future<void> _syncTimezone() async {
    try {
      final prefs = await _getPrefs();
      await _service.rescheduleIfTimezoneChanged(prefs);
    } catch (e, st) {
      _log.error('Foreground timezone sync failed', error: e, stackTrace: st);
    }
  }
}
