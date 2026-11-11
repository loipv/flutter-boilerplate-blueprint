import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blueprint_app/core/l10n/locale_provider.dart';

void main() {
  ProviderContainer createContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('localeProvider', () {
    test('Given no stored value, When built, Then null', () async {
      final c = createContainer();

      expect(await c.read(localeProvider.future), isNull);
    });

    test("Given stored 'vi', When built, Then Locale('vi')", () async {
      SharedPreferences.setMockInitialValues({'locale_code': 'vi'});
      final c = createContainer();

      expect(await c.read(localeProvider.future), const Locale('vi'));
    });

    test("Given stored 'fr' (unsupported), When built, Then null", () async {
      SharedPreferences.setMockInitialValues({'locale_code': 'fr'});
      final c = createContainer();

      expect(await c.read(localeProvider.future), isNull);
    });

    test(
      "Given setLocale(Locale('vi')), When called, Then state is vi and prefs 'locale_code' is 'vi'",
      () async {
        final c = createContainer();
        await c.read(localeProvider.future);

        await c.read(localeProvider.notifier).setLocale(const Locale('vi'));

        expect(c.read(localeProvider).value, const Locale('vi'));
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('locale_code'), 'vi');
      },
    );

    test(
      "Given stored 'vi', When setLocale(null), Then state is null and 'locale_code' is removed",
      () async {
        SharedPreferences.setMockInitialValues({'locale_code': 'vi'});
        final c = createContainer();
        await c.read(localeProvider.future);

        await c.read(localeProvider.notifier).setLocale(null);

        expect(c.read(localeProvider).value, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('locale_code'), isFalse);
      },
    );
  });
}
