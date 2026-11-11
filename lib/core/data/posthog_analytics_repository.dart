// BEGIN_POSTHOG
import 'package:posthog_flutter/posthog_flutter.dart';
// END_POSTHOG
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:blueprint_app/core/domain/analytics_repository.dart';
// BEGIN_POSTHOG
import 'package:blueprint_app/core/utils/app_logger.dart';
// END_POSTHOG

part 'posthog_analytics_repository.g.dart';

/// PostHog-backed implementation of [AnalyticsRepository].
///
/// This is the ONLY file in the codebase that imports `posthog_flutter`.
/// Confined to `core/data/` per the SDK confinement rule. When PostHog is
/// disabled at scaffold time the method bodies become no-ops; the class still
/// implements [AnalyticsRepository] so callers remain unchanged.
class PostHogAnalyticsRepository implements AnalyticsRepository {
  PostHogAnalyticsRepository(
    // BEGIN_POSTHOG
    this._posthog,
    // END_POSTHOG
  );

  // BEGIN_POSTHOG
  final Posthog _posthog;
  static const _log = AppLogger('PostHogAnalyticsRepository');
  // END_POSTHOG

  @override
  Future<void> captureEvent(
    String eventName, {
    Map<String, Object>? properties,
  }) async {
    // BEGIN_POSTHOG
    try {
      await _posthog.capture(eventName: eventName, properties: properties);
    } catch (e, st) {
      // Swallow: analytics must never crash the app.
      _log.error('captureEvent failed', error: e, stackTrace: st);
    }
    // END_POSTHOG
  }

  @override
  Future<void> captureScreen(String screenName) async {
    // BEGIN_POSTHOG
    try {
      await _posthog.screen(screenName: screenName);
    } catch (e, st) {
      _log.error('captureScreen failed', error: e, stackTrace: st);
    }
    // END_POSTHOG
  }

  @override
  Future<void> reset() async {
    // BEGIN_POSTHOG
    try {
      await _posthog.reset();
    } catch (e, st) {
      _log.error('reset failed', error: e, stackTrace: st);
    }
    // END_POSTHOG
  }
}

/// Exposes the ABSTRACT type so consumers never depend on PostHog directly.
@Riverpod(keepAlive: true)
PostHogAnalyticsRepository analyticsRepository(Ref ref) {
  return PostHogAnalyticsRepository(
    // BEGIN_POSTHOG
    Posthog(),
    // END_POSTHOG
  );
}
