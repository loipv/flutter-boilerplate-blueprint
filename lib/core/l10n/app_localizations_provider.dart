import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:blueprint_app/core/l10n/locale_provider.dart';
import 'package:blueprint_app/core/l10n/resolve_app_locale.dart';
import 'package:blueprint_app/l10n/generated/app_localizations.dart';

part 'app_localizations_provider.g.dart';

/// Maps a stored language code (or `null`) to the strings to use.
///
/// Unsupported or missing codes fall back to the first supported [system]
/// locale, then English. Usable without Riverpod (e.g. background isolates).
AppLocalizations appLocalizationsFor(String? storedCode, List<Locale> system) {
  final chosen = storedCode == null ? null : Locale(storedCode);
  return lookupAppLocalizations(resolveAppLocale(chosen, system));
}

/// Localized strings for code that has no [BuildContext] (notifiers, services).
///
/// Resolves the chosen locale, falling back to the device locale, then English.
@riverpod
AppLocalizations appLocalizations(Ref ref) {
  final chosen = ref.watch(localeProvider).value;
  return appLocalizationsFor(
    chosen?.languageCode,
    WidgetsBinding.instance.platformDispatcher.locales,
  );
}
