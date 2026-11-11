import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/core/l10n/locale_provider.dart';
import 'package:blueprint_app/core/theme/app_theme.dart';
import 'package:blueprint_app/l10n/generated/app_localizations.dart';

/// Pumps [child] inside a `ProviderScope` with [overrides] and a themed
/// `MaterialApp` + `Scaffold`, then settles.
///
/// A non-null [locale] pins the app locale. When null, the locale follows
/// `localeProvider` and falls back to English.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Locale? locale,
}) async {
  Widget app(Locale resolved) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: resolved,
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: locale != null
          ? app(locale)
          : Consumer(
              builder: (context, ref, _) =>
                  app(ref.watch(localeProvider).value ?? const Locale('en')),
            ),
    ),
  );
  await tester.pumpAndSettle();
}
