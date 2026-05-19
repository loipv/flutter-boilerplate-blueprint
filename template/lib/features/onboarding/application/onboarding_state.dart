import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_state.freezed.dart';

@freezed
abstract class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(false) bool isComplete,
    @Default(0) int currentStep,
    @Default(ThemeMode.system) ThemeMode themeMode,
    // TODO: add app-specific onboarding state fields here, e.g.:
    // String? selectedPlan,
    // bool notificationsGranted,
  }) = _OnboardingState;
}
