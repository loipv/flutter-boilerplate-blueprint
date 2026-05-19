import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:__APP_PACKAGE__/core/theme/theme_provider.dart';
import 'package:__APP_PACKAGE__/core/utils/app_logger.dart';
import 'package:__APP_PACKAGE__/features/auth/data/firebase_auth_repository.dart';
import 'package:__APP_PACKAGE__/features/auth/domain/user_preferences.dart';
import 'package:__APP_PACKAGE__/features/onboarding/application/onboarding_state.dart';
import 'package:__APP_PACKAGE__/features/onboarding/data/onboarding_repository.dart';
import 'package:__APP_PACKAGE__/features/user_profile/data/firebase_user_repository.dart';

part 'onboarding_controller.g.dart';

@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  static const _log = AppLogger('OnboardingController');

  @override
  FutureOr<OnboardingState> build() async {
    final repository = await ref.watch(onboardingRepositoryProvider.future);
    return OnboardingState(isComplete: repository.isOnboardingComplete);
  }

  void setTheme(ThemeMode mode) {
    _update((s) => s.copyWith(themeMode: mode));
    ref.read(themeNotifierProvider.notifier).setTheme(mode);
  }

  void nextStep() => _update((s) => s.copyWith(currentStep: s.currentStep + 1));

  /// Marks onboarding complete locally (SharedPreferences) AND in Firestore.
  Future<void> completeOnboarding() async {
    await markLocallyComplete();
    await _persistToFirestore();
  }

  /// Marks complete in memory and SharedPreferences only.
  /// Call this BEFORE sign-in to prevent the router from briefly
  /// redirecting to onboarding while the auth state updates.
  Future<void> markLocallyComplete() async {
    _update((s) => s.copyWith(isComplete: true));
    final repo = ref.read(onboardingRepositoryProvider).value;
    await repo?.setOnboardingComplete();
  }

  Future<void> _persistToFirestore() async {
    final currentState = state.requireValue;
    final authRepo = ref.read(authRepositoryProvider);
    final userRepo = ref.read(userRepositoryProvider);
    final user = authRepo.currentUser;
    if (user == null) {
      _log.warning(
        'No current user; skipping Firestore onboarding persistence',
      );
      return;
    }

    _log.info('Persisting onboarding; theme: ${currentState.themeMode}');

    final prefs = UserPreferences(
      themeMode: currentState.themeMode,
      hapticsEnabled: true,
    );

    await userRepo.savePreferences(user.id, prefs);
    await userRepo.markOnboardingComplete(user.id);
  }

  Future<void> resetOnboarding() async {
    final repo = await ref.read(onboardingRepositoryProvider.future);
    await repo.resetOnboarding();
    state = const AsyncValue.data(OnboardingState(isComplete: false));
  }

  void _update(OnboardingState Function(OnboardingState) cb) {
    state = AsyncValue.data(cb(state.requireValue));
  }
}
