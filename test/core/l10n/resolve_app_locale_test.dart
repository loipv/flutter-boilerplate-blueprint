import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/core/l10n/resolve_app_locale.dart';
import 'package:blueprint_app/l10n/generated/app_localizations.dart';

void main() {
  group('resolveAppLocale', () {
    test('Given chosen vi, When resolved with system [en], Then Locale vi', () {
      expect(
        resolveAppLocale(const Locale('vi'), const [Locale('en')]),
        const Locale('vi'),
      );
    });

    test('Given chosen fr (unsupported), When resolved with system [vi_VN], '
        'Then Locale vi', () {
      expect(
        resolveAppLocale(const Locale('fr'), const [Locale('vi', 'VN')]),
        const Locale('vi'),
      );
    });

    test(
      'Given no choice and system [vi_VN], When resolved, Then Locale vi',
      () {
        final result = resolveAppLocale(null, const [Locale('vi', 'VN')]);
        expect(result.languageCode, 'vi');
        expect(AppLocalizations.supportedLocales, contains(result));
      },
    );

    test('Given no choice and system [fr_FR, vi_VN], When resolved, '
        'Then Locale vi', () {
      expect(
        resolveAppLocale(null, const [Locale('fr', 'FR'), Locale('vi', 'VN')]),
        const Locale('vi'),
      );
    });

    test(
      'Given no choice and system [fr_FR], When resolved, Then Locale en',
      () {
        expect(
          resolveAppLocale(null, const [Locale('fr', 'FR')]),
          const Locale('en'),
        );
      },
    );

    test('Given no choice and an empty system list, When resolved, '
        'Then Locale en', () {
      expect(resolveAppLocale(null, const []), const Locale('en'));
    });

    test(
      'Given supported [en] and system [vi], When resolved, Then Locale en',
      () {
        expect(
          resolveAppLocale(
            null,
            const [Locale('vi')],
            supported: const [Locale('en')],
          ),
          const Locale('en'),
        );
      },
    );
  });
}
