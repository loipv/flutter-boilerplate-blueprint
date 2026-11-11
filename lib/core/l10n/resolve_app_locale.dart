import 'dart:ui';

import 'package:blueprint_app/l10n/generated/app_localizations.dart';

/// Picks the locale the app should use.
///
/// A [chosen] locale wins when its language is supported. Otherwise the first
/// [system] locale whose language is supported is used, then English, then the
/// first supported locale. The result is always a member of [supported].
Locale resolveAppLocale(
  Locale? chosen,
  List<Locale> system, {
  List<Locale> supported = AppLocalizations.supportedLocales,
}) {
  Locale? match(Locale locale) {
    for (final candidate in supported) {
      if (candidate.languageCode == locale.languageCode) return candidate;
    }
    return null;
  }

  if (chosen != null) {
    final hit = match(chosen);
    if (hit != null) return hit;
  }
  for (final locale in system) {
    final hit = match(locale);
    if (hit != null) return hit;
  }
  return supported.firstWhere(
    (l) => l.languageCode == 'en',
    orElse: () => supported.first,
  );
}
