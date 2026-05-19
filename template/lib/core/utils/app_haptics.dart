import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:__APP_PACKAGE__/core/providers/haptics_provider.dart';

/// Drop-in replacement for [HapticFeedback] that respects the user's
/// haptics preference stored in their profile.
///
/// Always call with the widget's `ref`. Never call `HapticFeedback.*()` directly.
/// The only permitted exception is the haptics toggle in SettingsScreen, which
/// fires `HapticFeedback.lightImpact()` directly when turning ON (so the user
/// gets confirmation before the Firestore write completes).
abstract final class AppHaptics {
  static void lightImpact(WidgetRef ref) {
    if (ref.read(hapticsEnabledProvider)) HapticFeedback.lightImpact();
  }

  static void mediumImpact(WidgetRef ref) {
    if (ref.read(hapticsEnabledProvider)) HapticFeedback.mediumImpact();
  }

  static void selectionClick(WidgetRef ref) {
    if (ref.read(hapticsEnabledProvider)) HapticFeedback.selectionClick();
  }

  static void heavyImpact(WidgetRef ref) {
    if (ref.read(hapticsEnabledProvider)) HapticFeedback.heavyImpact();
  }
}
