import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:blueprint_app/core/l10n/locale_provider.dart';
import 'package:blueprint_app/core/l10n/resolve_app_locale.dart';
import 'package:blueprint_app/l10n/generated/app_localizations.dart';

part 'app_localizations_provider.g.dart';

/// Localized strings for code that has no [BuildContext] (notifiers, services).
///
/// Resolves the chosen locale, falling back to the device locale, then English.
@riverpod
AppLocalizations appLocalizations(Ref ref) {
  final chosen = ref.watch(localeProvider).value;
  final locale = resolveAppLocale(
    chosen,
    WidgetsBinding.instance.platformDispatcher.locales,
  );
  return lookupAppLocalizations(locale);
}
