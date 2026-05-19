import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:__APP_PACKAGE__/core/providers/shared_preferences_provider.dart';

part 'theme_provider.g.dart';

/// Synchronous read of the current theme mode; falls back to system while loading.
///
/// Use this in widgets that need a `ThemeMode` value directly (e.g. DropdownButton).
@riverpod
ThemeMode themeMode(Ref ref) =>
    ref.watch(themeNotifierProvider).value ?? ThemeMode.system;

/// Persists theme mode to SharedPreferences.
///
/// Optional enhancement: also persist to Firestore so the theme syncs across
/// devices. To add that, inject UserRepository and call savePreferences()
/// inside setTheme() after writing to SharedPreferences.
@Riverpod(keepAlive: true)
class ThemeNotifier extends _$ThemeNotifier {
  static const _storageKey = 'theme_mode';

  @override
  Future<ThemeMode> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final stored = prefs.getString(_storageKey);
    if (stored == 'light') return ThemeMode.light;
    if (stored == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = AsyncValue.data(mode);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (mode == ThemeMode.system) {
      prefs.remove(_storageKey);
    } else {
      prefs.setString(_storageKey, mode.name);
    }
  }

  /// Reverts to system default. Call on sign-out so the next session
  /// starts clean.
  Future<void> resetToSystem() async {
    state = const AsyncValue.data(ThemeMode.system);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    prefs.remove(_storageKey);
  }
}
