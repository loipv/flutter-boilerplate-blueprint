import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:blueprint_app/core/providers/shared_preferences_provider.dart';
import 'package:blueprint_app/core/utils/app_logger.dart';
import 'package:blueprint_app/l10n/generated/app_localizations.dart';

part 'locale_provider.g.dart';

/// Persists the user's chosen language to SharedPreferences.
///
/// State is `null` when the user has not chosen a language, meaning the app
/// follows the device language.
@Riverpod(keepAlive: true)
class LocaleNotifier extends _$LocaleNotifier {
  /// SharedPreferences key holding the chosen language code.
  static const storageKey = 'locale_code';
  static const _log = AppLogger('LocaleNotifier');

  @override
  Future<Locale?> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final stored = prefs.getString(storageKey);
    if (stored == null) return null;

    final isSupported = AppLocalizations.supportedLocales.any(
      (locale) => locale.languageCode == stored,
    );
    if (!isSupported) {
      _log.warning('Ignoring unsupported stored locale "$stored"');
      return null;
    }
    return Locale(stored);
  }

  /// Sets the app language. Pass `null` to follow the device language.
  Future<void> setLocale(Locale? locale) async {
    state = AsyncValue.data(locale);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (locale == null) {
      await prefs.remove(storageKey);
    } else {
      await prefs.setString(storageKey, locale.languageCode);
    }
  }
}
