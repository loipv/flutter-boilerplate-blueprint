import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:blueprint_app/core/l10n/l10n_extension.dart';
import 'package:blueprint_app/core/l10n/locale_provider.dart';
import 'package:blueprint_app/core/presentation/utils/app_snack_bar.dart';
import 'package:blueprint_app/core/providers/haptics_provider.dart';
import 'package:blueprint_app/core/theme/app_spacing.dart';
import 'package:blueprint_app/core/theme/app_typography.dart';
import 'package:blueprint_app/core/theme/theme_provider.dart';
import 'package:blueprint_app/core/errors/failure.dart';
import 'package:blueprint_app/features/auth/application/auth_controller.dart';
import 'package:blueprint_app/features/auth/domain/user_entity.dart';
import 'package:blueprint_app/features/auth/presentation/auth_failure_message.dart';
// Unused only when both Apple and Google sign-in are removed.
// ignore: unused_import
import 'package:blueprint_app/features/auth/presentation/widgets/auth_button.dart';
import 'package:blueprint_app/features/settings/application/settings_controller.dart';
import 'package:blueprint_app/features/user_profile/application/user_profile_providers.dart';
import 'package:blueprint_app/l10n/generated/app_localizations.dart';
// BEGIN_ADS
import 'package:blueprint_app/features/ads/presentation/ad_privacy_options_tile.dart';
// END_ADS
// BEGIN_NOTIFICATIONS_IMPORTS
import 'package:blueprint_app/core/services/notification_service.dart';

// END_NOTIFICATIONS_IMPORTS

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // BEGIN_APPLE
  bool _isLoadingApple = false;
  // END_APPLE
  // BEGIN_GOOGLE
  bool _isLoadingGoogle = false;
  // END_GOOGLE

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final profileState = ref.watch(userProfileStreamProvider);
    final user = profileState.value ?? authState.value;
    final isAnonymous = authState.value?.isAnonymous ?? true;
    final themeMode = ref.watch(themeModeProvider);
    final hapticsEnabled = ref.watch(hapticsEnabledProvider);
    // BEGIN_NOTIFICATIONS_IMPORTS
    final notificationTime = user?.preferences.notificationTime;
    // END_NOTIFICATIONS_IMPORTS

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: AppTypography.titleLarge),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.p4,
            vertical: AppSpacing.p2,
          ),
          children: [
            _SectionHeader('Appearance'),
            const Gap(AppSpacing.p2),
            _ThemeTile(currentMode: themeMode),
            const Gap(AppSpacing.p2),
            const _LanguageTile(),
            const Gap(AppSpacing.p4),
            _SectionHeader('Accessibility'),
            const Gap(AppSpacing.p2),
            SwitchListTile(
              secondary: const Icon(LucideIcons.vibrate),
              title: const Text('Haptic feedback'),
              value: hapticsEnabled,
              onChanged: (val) => ref
                  .read(settingsControllerProvider.notifier)
                  .updateHaptics(val),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // BEGIN_NOTIFICATIONS_SECTION
            const Gap(AppSpacing.p4),
            _SectionHeader('Reminders'),
            const Gap(AppSpacing.p2),
            SwitchListTile(
              secondary: const Icon(LucideIcons.bell),
              title: const Text('Daily reminder'),
              subtitle: Text(
                notificationTime == null
                    ? 'Off'
                    : 'Scheduled for ${_formatTime(context, notificationTime)}',
              ),
              value: notificationTime != null,
              onChanged: user == null
                  ? null
                  : (enabled) =>
                        _toggleDailyReminder(context, enabled: enabled),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            if (notificationTime != null) ...[
              const Gap(AppSpacing.p2),
              ListTile(
                leading: const Icon(LucideIcons.clock3),
                title: const Text('Reminder time'),
                subtitle: Text(_formatTime(context, notificationTime)),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: user == null
                    ? null
                    : () => _pickReminderTime(
                        context,
                        initialTime: notificationTime,
                      ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
            // END_NOTIFICATIONS_SECTION
            // BEGIN_ADS
            AdPrivacyOptionsTile(header: _SectionHeader('Privacy')),
            // END_ADS
            const Gap(AppSpacing.p8),
            _SectionHeader('Account'),
            const Gap(AppSpacing.p2),
            if (user != null) ...[
              _AccountSummaryTile(user: user),
              const Gap(AppSpacing.p2),
            ],
            if (isAnonymous) ...[
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Save your progress'),
                subtitle: Text(
                  'Link Apple or Google to keep your data across devices.',
                ),
              ),
              // BEGIN_APPLE
              AuthButton(
                provider: AuthProvider.apple,
                isLoading: _isLoadingApple,
                onTap: () => _linkAccount(
                  () => ref
                      .read(authControllerProvider.notifier)
                      .signInWithApple(),
                  setLoading: (v) => setState(() => _isLoadingApple = v),
                  method: SignInMethod.apple,
                ),
              ),
              const Gap(AppSpacing.p3),
              // END_APPLE
              // BEGIN_GOOGLE
              AuthButton(
                provider: AuthProvider.google,
                isLoading: _isLoadingGoogle,
                onTap: () => _linkAccount(
                  () => ref
                      .read(authControllerProvider.notifier)
                      .signInWithGoogle(),
                  setLoading: (v) => setState(() => _isLoadingGoogle = v),
                  method: SignInMethod.google,
                ),
              ),
              // END_GOOGLE
              const Gap(AppSpacing.p4),
            ],
            if (user != null)
              ListTile(
                leading: Icon(
                  LucideIcons.logOut,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Sign out',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => _confirmSignOut(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ListTile(
              leading: Icon(
                LucideIcons.trash2,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete account',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => _confirmDeleteAccount(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Unused only when both Apple and Google sign-in are removed.
  // ignore: unused_element
  Future<void> _linkAccount(
    Future<void> Function() signIn, {
    required void Function(bool) setLoading,
    required SignInMethod method,
  }) async {
    void update(bool value) {
      if (mounted) setLoading(value);
    }

    update(true);
    try {
      await signIn();
      if (mounted) {
        AppSnackBar.success(context, 'Account linked successfully.');
      }
    } on Failure catch (e) {
      final isCanceled = e.maybeWhen(
        auth: (code) => code == 'canceled',
        orElse: () => false,
      );
      if (mounted && !isCanceled) {
        final message = authFailureMessage(
          e,
          method: method,
          l10n: context.l10n,
        );
        AppSnackBar.error(context, message ?? context.l10n.authSignInFailed);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, context.l10n.authSignInFailed);
      }
    } finally {
      update(false);
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your account and associated data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final message = await ref
        .read(authControllerProvider.notifier)
        .deleteAccount();
    if (!context.mounted || message == null) return;
    AppSnackBar.error(context, message);
  }

  // BEGIN_NOTIFICATIONS_HELPERS
  Future<void> _toggleDailyReminder(
    BuildContext context, {
    required bool enabled,
  }) async {
    if (!enabled) {
      await ref
          .read(settingsControllerProvider.notifier)
          .updateNotificationTime(null);
      return;
    }

    final granted = await ref
        .read(notificationServiceProvider)
        .requestPermissions();
    if (!context.mounted) return;
    if (granted == false) {
      AppSnackBar.error(
        context,
        'Notifications are disabled for this app. Enable them in system settings and try again.',
      );
      return;
    }

    await _pickReminderTime(context, initialTime: '08:00');
  }

  Future<void> _pickReminderTime(
    BuildContext context, {
    required String initialTime,
  }) async {
    final parsed =
        _parseTime(initialTime) ?? const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: parsed);
    if (picked == null) return;

    final hour = picked.hour.toString().padLeft(2, '0');
    final minute = picked.minute.toString().padLeft(2, '0');
    await ref
        .read(settingsControllerProvider.notifier)
        .updateNotificationTime('$hour:$minute');
  }

  TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(BuildContext context, String value) {
    final parsed = _parseTime(value);
    if (parsed == null) return value;
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(parsed);
  }

  // END_NOTIFICATIONS_HELPERS
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.p2),
      child: Text(
        title,
        style: AppTypography.labelMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile({required this.currentMode});
  final ThemeMode currentMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(_iconFor(currentMode)),
      title: const Text('Theme'),
      trailing: DropdownButton<ThemeMode>(
        value: currentMode,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
          DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
        ],
        onChanged: (mode) {
          if (mode != null) {
            ref.read(settingsControllerProvider.notifier).updateThemeMode(mode);
            ref.read(themeProvider.notifier).setTheme(mode);
          }
        },
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  IconData _iconFor(ThemeMode mode) => switch (mode) {
    ThemeMode.light => LucideIcons.sun,
    ThemeMode.dark => LucideIcons.moon,
    ThemeMode.system => LucideIcons.monitor,
  };
}

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider).value;
    return ListTile(
      leading: const Icon(LucideIcons.languages),
      title: Text(context.l10n.settingsLanguage),
      trailing: DropdownButton<Locale?>(
        value: current,
        underline: const SizedBox.shrink(),
        items: [
          DropdownMenuItem<Locale?>(
            child: Text(context.l10n.settingsLanguageSystem),
          ),
          for (final locale in AppLocalizations.supportedLocales)
            DropdownMenuItem<Locale?>(
              value: locale,
              child: Text(lookupAppLocalizations(locale).languageNativeName),
            ),
        ],
        onChanged: (locale) {
          // Local switch first so the UI updates even if the save fails.
          ref.read(localeProvider.notifier).setLocale(locale);
          ref
              .read(settingsControllerProvider.notifier)
              .updateLanguage(locale?.languageCode);
        },
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _AccountSummaryTile extends StatelessWidget {
  const _AccountSummaryTile({required this.user});

  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    final subtitle = user.isAnonymous
        ? 'Guest session'
        : user.email ?? _providerLabel(user.signInProvider);

    return ListTile(
      leading: CircleAvatar(
        child: Text(
          (user.displayName ?? user.email ?? 'G').substring(0, 1).toUpperCase(),
        ),
      ),
      title: Text(user.displayName ?? user.email ?? 'Guest'),
      subtitle: Text(subtitle),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  String _providerLabel(String? provider) => switch (provider) {
    'apple' => 'Signed in with Apple',
    'google' => 'Signed in with Google',
    _ => 'Signed in',
  };
}
