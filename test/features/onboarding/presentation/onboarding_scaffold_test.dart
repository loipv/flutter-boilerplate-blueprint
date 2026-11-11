import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/features/onboarding/presentation/onboarding_scaffold.dart';
import 'package:blueprint_app/l10n/generated/app_localizations.dart';

void main() {
  /// Pumps the scaffold under a plain MaterialApp: no GoRouter, so no
  /// GoRouterState ancestor, and returns the settled progress value.
  Future<double?> pumpScaffold(WidgetTester tester, String path) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: OnboardingScaffold(path: path, child: const Text('step')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value;
  }

  group('OnboardingScaffold', () {
    // Regression: GoRouterState.of threw during the onboarding -> Home
    // redirect on a device. The widget must not depend on GoRouterState.
    testWidgets(
      'Given no GoRouterState ancestor, When it builds for /onboarding/theme, Then it renders the child at step 3 of 4',
      (tester) async {
        final progress = await pumpScaffold(tester, '/onboarding/theme');

        expect(tester.takeException(), isNull);
        expect(find.text('step'), findsOneWidget);
        expect(progress, 3 / 4);
      },
    );

    testWidgets(
      'Given the login prompt path, When it builds, Then the progress bar is full',
      (tester) async {
        expect(await pumpScaffold(tester, '/onboarding/login-prompt'), 1.0);
      },
    );

    testWidgets(
      'Given a path outside the onboarding steps, When it builds, Then the progress bar is empty',
      (tester) async {
        expect(await pumpScaffold(tester, '/elsewhere'), 0.0);
      },
    );
  });
}
