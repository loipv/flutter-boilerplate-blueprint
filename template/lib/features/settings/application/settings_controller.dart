import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:__APP_PACKAGE__/core/utils/app_logger.dart';
import 'package:__APP_PACKAGE__/features/auth/application/auth_controller.dart';
import 'package:__APP_PACKAGE__/features/auth/domain/user_preferences.dart';
import 'package:__APP_PACKAGE__/features/user_profile/application/user_profile_providers.dart';
import 'package:__APP_PACKAGE__/features/user_profile/data/firebase_user_repository.dart';

part 'settings_controller.g.dart';

@riverpod
class SettingsController extends _$SettingsController {
  static const _log = AppLogger('SettingsController');

  @override
  FutureOr<void> build() {}

  Future<void> updateThemeMode(ThemeMode mode) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final existing = await ref
          .read(userRepositoryProvider)
          .getUserStream(user.id)
          .first;
      final prefs = (existing?.preferences ?? const UserPreferences()).copyWith(
        themeMode: mode,
      );
      await ref.read(userRepositoryProvider).savePreferences(user.id, prefs);
      _log.info('Theme updated to ${mode.name}');
    });
  }

  Future<void> updateHaptics(bool enabled) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final existing = await ref
          .read(userRepositoryProvider)
          .getUserStream(user.id)
          .first;
      final prefs = (existing?.preferences ?? const UserPreferences()).copyWith(
        hapticsEnabled: enabled,
      );
      await ref.read(userRepositoryProvider).savePreferences(user.id, prefs);
      _log.info('Haptics updated to $enabled');
    });
  }

  Future<void> updateNotificationTime(String? time) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final existing = await ref
          .read(userRepositoryProvider)
          .getUserStream(user.id)
          .first;
      final prefs = (existing?.preferences ?? const UserPreferences()).copyWith(
        notificationTime: time,
      );
      await ref.read(userRepositoryProvider).savePreferences(user.id, prefs);
      _log.info('Notification time updated to $time');
    });
  }

  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(authControllerProvider.notifier).deleteAccount();
    });
  }
}
