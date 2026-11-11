import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blueprint_app/core/theme/theme_provider.dart';

void main() {
  late ProviderContainer container;

  ProviderContainer createContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = createContainer();
  });

  group('themeProvider', () {
    test(
      'Given no stored value, When the notifier builds, Then the theme is ThemeMode.system',
      () async {
        expect(await container.read(themeProvider.future), ThemeMode.system);
      },
    );

    test(
      'Given a stored "light" value, When the notifier builds, Then the theme is ThemeMode.light',
      () async {
        SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
        final c = createContainer();

        expect(await c.read(themeProvider.future), ThemeMode.light);
      },
    );

    test(
      'Given a stored "dark" value, When the notifier builds, Then the theme is ThemeMode.dark',
      () async {
        SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
        final c = createContainer();

        expect(await c.read(themeProvider.future), ThemeMode.dark);
      },
    );

    test(
      'Given an unknown stored value, When the notifier builds, Then the theme falls back to ThemeMode.system',
      () async {
        SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
        final c = createContainer();

        expect(await c.read(themeProvider.future), ThemeMode.system);
      },
    );

    test(
      'Given the default theme, When setTheme(ThemeMode.dark) is called, Then the state is dark and "dark" is stored under theme_mode',
      () async {
        await container.read(themeProvider.future);

        await container.read(themeProvider.notifier).setTheme(ThemeMode.dark);

        expect(container.read(themeProvider).value, ThemeMode.dark);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('theme_mode'), 'dark');
      },
    );

    test(
      'Given a stored dark theme, When setTheme(ThemeMode.system) is called, Then the state is system and theme_mode is removed',
      () async {
        SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
        final c = createContainer();
        await c.read(themeProvider.future);

        await c.read(themeProvider.notifier).setTheme(ThemeMode.system);

        expect(c.read(themeProvider).value, ThemeMode.system);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('theme_mode'), isFalse);
      },
    );

    test(
      'Given a dark theme was set, When resetToSystem is called, Then the state is system and theme_mode is removed',
      () async {
        await container.read(themeProvider.future);
        await container.read(themeProvider.notifier).setTheme(ThemeMode.dark);

        await container.read(themeProvider.notifier).resetToSystem();

        expect(container.read(themeProvider).value, ThemeMode.system);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('theme_mode'), isFalse);
      },
    );
  });

  group('themeMode', () {
    test(
      'Given the theme is still loading, When reading themeMode, Then it falls back to ThemeMode.system',
      () {
        SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
        final c = createContainer();

        expect(c.read(themeModeProvider), ThemeMode.system);
      },
    );

    test(
      'Given a stored dark theme, When the theme has loaded, Then themeMode is ThemeMode.dark',
      () async {
        SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
        final c = createContainer();
        c.listen(themeModeProvider, (_, _) {});
        await c.read(themeProvider.future);

        expect(c.read(themeModeProvider), ThemeMode.dark);
      },
    );
  });
}
