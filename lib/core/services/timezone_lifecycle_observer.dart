import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blueprint_app/core/services/notification_service.dart';
import 'package:blueprint_app/core/utils/app_logger.dart';
import 'package:blueprint_app/l10n/generated/app_localizations.dart';

class TimezoneLifecycleObserver extends WidgetsBindingObserver {
  TimezoneLifecycleObserver({
    required NotificationService notificationService,
    required Future<SharedPreferences> Function() getPrefs,
    required AppLocalizations Function() getL10n,
  }) : _service = notificationService,
       _getPrefs = getPrefs,
       _getL10n = getL10n;

  static const _log = AppLogger('TimezoneLifecycleObserver');

  final NotificationService _service;
  final Future<SharedPreferences> Function() _getPrefs;
  final AppLocalizations Function() _getL10n;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncTimezone();
    }
  }

  Future<void> _syncTimezone() async {
    try {
      final prefs = await _getPrefs();
      await _service.rescheduleIfTimezoneChanged(prefs, _getL10n());
    } catch (e, st) {
      _log.error('Foreground timezone sync failed', error: e, stackTrace: st);
    }
  }
}
