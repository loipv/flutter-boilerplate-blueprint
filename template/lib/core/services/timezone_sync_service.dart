import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:workmanager/workmanager.dart';
import 'package:__APP_PACKAGE__/core/services/notification_service.dart';
import 'package:__APP_PACKAGE__/core/utils/app_logger.dart';

const _kTaskName = '__APP_PACKAGE__.timezone.sync';

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
      await service.rescheduleIfTimezoneChanged(prefs);
      log.info('Background timezone sync task completed');
      return true;
    } catch (e, st) {
      log.error('Background timezone sync failed', error: e, stackTrace: st);
      return false;
    }
  });
}
