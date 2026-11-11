import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/core/l10n/l10n_extension.dart';
import 'package:blueprint_app/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('Given a MaterialApp with locale vi, When context.l10n is read, '
      'Then languageNativeName is Tiếng Việt', (tester) async {
    String? name;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            name = context.l10n.languageNativeName;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(name, 'Tiếng Việt');
  });
}
