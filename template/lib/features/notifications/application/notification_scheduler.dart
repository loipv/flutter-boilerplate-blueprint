import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:__APP_PACKAGE__/core/providers/shared_preferences_provider.dart';
import 'package:__APP_PACKAGE__/core/services/notification_service.dart';
import 'package:__APP_PACKAGE__/core/utils/app_logger.dart';
import 'package:__APP_PACKAGE__/features/user_profile/application/user_profile_providers.dart';

/// Listens for notification taps so apps can centralize deep-link handling.
///
/// The template leaves payload routing intentionally minimal. Replace the TODO
/// inside [_NotificationSchedulerState._handlePayload] with app-specific
/// navigation once you know what each notification should open.
class NotificationScheduler extends ConsumerStatefulWidget {
  const NotificationScheduler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationScheduler> createState() =>
      _NotificationSchedulerState();
}

class _NotificationSchedulerState extends ConsumerState<NotificationScheduler> {
  static const _log = AppLogger('NotificationScheduler');
  StreamSubscription<String?>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref
        .read(notificationServiceProvider)
        .onNotificationTap
        .listen(_handlePayload);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    // TODO: Add app-specific navigation based on the notification payload.
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProfileStreamProvider, (previous, next) {
      next.when(
        data: (user) async {
          final previousTime = previous?.value?.preferences.notificationTime;
          final nextTime = user?.preferences.notificationTime;
          if (previousTime == nextTime) return;

          final service = ref.read(notificationServiceProvider);
          if (nextTime == null || nextTime.isEmpty) {
            await service.cancelDailyNotification();
            final prefs = await ref.read(sharedPreferencesProvider.future);
            await prefs.remove(NotificationService.kNotificationHour);
            await prefs.remove(NotificationService.kNotificationMinute);
            return;
          }

          final parts = nextTime.split(':');
          if (parts.length != 2) {
            _log.warning('Ignoring invalid notification time: $nextTime');
            return;
          }

          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour == null || minute == null) {
            _log.warning('Ignoring invalid notification time: $nextTime');
            return;
          }

          await service.scheduleDailyNotification(
            time: TimeOfDay(hour: hour, minute: minute),
          );

          final prefs = await ref.read(sharedPreferencesProvider.future);
          await prefs.setInt(NotificationService.kNotificationHour, hour);
          await prefs.setInt(NotificationService.kNotificationMinute, minute);
        },
        error: (error, stackTrace) => _log.error(
          'Notification sync failed',
          error: error,
          stackTrace: stackTrace,
        ),
        loading: () {},
      );
    });

    return widget.child;
  }
}
