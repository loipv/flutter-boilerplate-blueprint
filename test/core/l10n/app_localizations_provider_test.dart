import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blueprint_app/core/l10n/app_localizations_provider.dart';
import 'package:blueprint_app/core/l10n/locale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer createContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('appLocalizationsFor', () {
    test(
      'Given no stored code and system [vi_VN], When resolved, Then Vietnamese',
      () {
        final l10n = appLocalizationsFor(null, const [Locale('vi', 'VN')]);

        expect(l10n.localeName, 'vi');
      },
    );

    test('Given stored vi and system [en], When resolved, Then Vietnamese', () {
      final l10n = appLocalizationsFor('vi', const [Locale('en')]);

      expect(l10n.localeName, 'vi');
    });

    test(
      'Given unsupported stored fr and system [en], When resolved, Then English',
      () {
        final l10n = appLocalizationsFor('fr', const [Locale('en')]);

        expect(l10n.localeName, 'en');
      },
    );
  });

  group('appLocalizationsProvider', () {
    test(
      "Given stored 'vi', When read, Then languageNativeName is 'Tiếng Việt'",
      () async {
        SharedPreferences.setMockInitialValues({'locale_code': 'vi'});
        final c = createContainer();
        await c.read(localeProvider.future);

        expect(
          c.read(appLocalizationsProvider).languageNativeName,
          'Tiếng Việt',
        );
      },
    );

    test(
      "Given no stored value and the test platform locale en_US, When read, Then languageNativeName is 'English'",
      () async {
        final c = createContainer();
        await c.read(localeProvider.future);

        expect(c.read(appLocalizationsProvider).languageNativeName, 'English');
      },
    );

    test(
      "Given stored 'en', When setLocale(vi) is called, Then a re-read returns Vietnamese",
      () async {
        SharedPreferences.setMockInitialValues({'locale_code': 'en'});
        final c = createContainer();
        await c.read(localeProvider.future);
        expect(c.read(appLocalizationsProvider).languageNativeName, 'English');

        await c.read(localeProvider.notifier).setLocale(const Locale('vi'));

        expect(
          c.read(appLocalizationsProvider).languageNativeName,
          'Tiếng Việt',
        );
      },
    );
  });
}
