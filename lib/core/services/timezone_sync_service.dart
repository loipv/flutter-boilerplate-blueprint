import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:workmanager/workmanager.dart';
import 'package:blueprint_app/core/l10n/resolve_app_locale.dart';
import 'package:blueprint_app/core/services/notification_service.dart';
import 'package:blueprint_app/core/utils/app_logger.dart';
import 'package:blueprint_app/l10n/generated/app_localizations.dart';

const _kTaskName = 'blueprint_app.timezone.sync';

class TimezoneSyncService {
  const TimezoneSyncService._();

  static const taskName = _kTaskName;

  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      _kTaskName,
      _kTaskName,
      frequency: const Duration(hours: 12),
      initialDelay: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}

@pragma('vm:entry-point')
void timezoneSyncCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    const log = AppLogger('TimezoneSyncCallback');
    log.info('Background timezone sync task started: $taskName');

    try {
      tz.initializeTimeZones();
      final prefs = await SharedPreferences.getInstance();
      final service = NotificationService();
      // No provider container in this isolate: resolve the language by hand.
      final code = prefs.getString('locale_code');
      final l10n = lookupAppLocalizations(
        resolveAppLocale(
          code == null ? null : Locale(code),
          WidgetsBinding.instance.platformDispatcher.locales,
        ),
      );
      await service.rescheduleIfTimezoneChanged(prefs, l10n);
      log.info('Background timezone sync task completed');
      return true;
    } catch (e, st) {
      log.error('Background timezone sync failed', error: e, stackTrace: st);
      return false;
    }
  });
}
