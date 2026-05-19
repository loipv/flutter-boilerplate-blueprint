import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:__APP_PACKAGE__/core/constants/app_constants.dart';
import 'package:__APP_PACKAGE__/core/providers/shared_preferences_provider.dart';

part 'onboarding_repository.g.dart';

/// SharedPreferences-backed persistence for onboarding completion state.
class OnboardingRepository {
  OnboardingRepository(this._prefs);
  final SharedPreferences _prefs;

  bool get isOnboardingComplete =>
      _prefs.getBool(AppConstants.onboardingCompleteKey) ?? false;

  Future<void> setOnboardingComplete() =>
      _prefs.setBool(AppConstants.onboardingCompleteKey, true);

  Future<void> resetOnboarding() =>
      _prefs.remove(AppConstants.onboardingCompleteKey);
}

@Riverpod(keepAlive: true)
Future<OnboardingRepository> onboardingRepository(Ref ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return OnboardingRepository(prefs);
}
