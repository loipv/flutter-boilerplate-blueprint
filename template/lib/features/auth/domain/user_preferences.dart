import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_preferences.freezed.dart';
part 'user_preferences.g.dart';

/// Per-user preferences stored in Firestore under `users/{uid}/preferences`.
///
/// Add app-specific preferences here (e.g. notificationTime, language, etc.).
@freezed
abstract class UserPreferences with _$UserPreferences {
  const factory UserPreferences({
    @Default(ThemeMode.system) ThemeMode themeMode,
    @Default(true) bool hapticsEnabled,
    // BEGIN_NOTIFICATIONS_PREF
    String? notificationTime,
    // END_NOTIFICATIONS_PREF
    // TODO: add your app-specific preferences here, e.g.:
    // @Default('en') String language,
  }) = _UserPreferences;

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      _$UserPreferencesFromJson(json);
}
