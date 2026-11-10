/// Backend-agnostic contract for product analytics.
///
/// Implementations must never receive or transmit PII (e.g. Firebase Auth UIDs).
/// All tracking is anonymous by design.
///
/// The concrete implementation lives in `core/data/posthog_analytics_repository.dart`.
abstract class AnalyticsRepository {
  /// Fires a named event with optional anonymous properties.
  /// [properties] must contain ONLY non-PII data.
  Future<void> captureEvent(
    String eventName, {
    Map<String, Object>? properties,
  });

  /// Fires a screen view event. Called automatically by GoRouter observers;
  /// expose here for manual use in edge cases.
  Future<void> captureScreen(String screenName);

  /// Resets the anonymous session. Call on sign-out so the next session
  /// starts with a fresh anonymous distinct ID.
  Future<void> reset();
}
