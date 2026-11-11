import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/features/auth/domain/user_preferences.dart';

void main() {
  group('UserPreferences defaults', () {
    test('Given no arguments, When constructed, Then defaults apply', () {
      const prefs = UserPreferences();

      expect(prefs.themeMode, ThemeMode.system);
      expect(prefs.hapticsEnabled, isTrue);
    });
  });

  group('toJson / fromJson', () {
    test('Given custom values, When round-tripped, Then they are equal', () {
      const prefs = UserPreferences(
        themeMode: ThemeMode.dark,
        hapticsEnabled: false,
      );

      expect(UserPreferences.fromJson(prefs.toJson()), prefs);
    });

    test(
      'Given languageCode vi, When round-tripped through JSON, Then it is preserved',
      () {
        const prefs = UserPreferences(languageCode: 'vi');

        expect(UserPreferences.fromJson(prefs.toJson()).languageCode, 'vi');
      },
    );

    test(
      'Given JSON without languageCode, When parsed, Then languageCode is null',
      () {
        expect(UserPreferences.fromJson(const {}).languageCode, isNull);
      },
    );

    test('Given an empty map, When parsed, Then defaults apply', () {
      expect(UserPreferences.fromJson(const {}), const UserPreferences());
    });
  });
}
