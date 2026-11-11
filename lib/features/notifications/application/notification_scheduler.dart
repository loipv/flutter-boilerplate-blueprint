import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blueprint_app/core/l10n/app_localizations_provider.dart';
import 'package:blueprint_app/core/providers/shared_preferences_provider.dart';
import 'package:blueprint_app/core/services/notification_service.dart';
import 'package:blueprint_app/core/utils/app_logger.dart';
import 'package:blueprint_app/features/user_profile/application/user_profile_providers.dart';

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

  Future<void> _schedule(String time) async {
    final parts = time.split(':');
    if (parts.length != 2) {
      _log.warning('Ignoring invalid notification time: $time');
      return;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      _log.warning('Ignoring invalid notification time: $time');
      return;
    }

    final l10n = ref.read(appLocalizationsProvider);
    await ref
        .read(notificationServiceProvider)
        .scheduleDailyNotification(
          time: TimeOfDay(hour: hour, minute: minute),
          title: l10n.notificationsDailyTitle,
          body: l10n.notificationsDailyBody,
          channelName: l10n.notificationsChannelName,
          channelDescription: l10n.notificationsChannelDescription,
        );

    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setInt(NotificationService.kNotificationHour, hour);
    await prefs.setInt(NotificationService.kNotificationMinute, minute);
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

          await _schedule(nextTime);
        },
        error: (error, stackTrace) => _log.error(
          'Notification sync failed',
          error: error,
          stackTrace: stackTrace,
        ),
        loading: () {},
      );
    });

    // Re-schedule with translated text when the app language changes.
    ref.listen(appLocalizationsProvider, (previous, next) {
      final time = ref
          .read(userProfileStreamProvider)
          .value
          ?.preferences
          .notificationTime;
      if (time == null || time.isEmpty) return;
      _schedule(time);
    });

    return widget.child;
  }
}
