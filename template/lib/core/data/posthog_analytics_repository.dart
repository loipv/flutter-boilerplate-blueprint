import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:__APP_PACKAGE__/core/domain/analytics_repository.dart';
import 'package:__APP_PACKAGE__/core/utils/app_logger.dart';

part 'posthog_analytics_repository.g.dart';

/// PostHog-backed implementation of [AnalyticsRepository].
///
/// This is the ONLY file in the codebase that imports `posthog_flutter`.
/// Confined to `core/data/` per the SDK confinement rule.
class PostHogAnalyticsRepository implements AnalyticsRepository {
  static const _log = AppLogger('PostHogAnalyticsRepository');

  @override
  Future<void> captureEvent(
    String eventName, {
    Map<String, Object>? properties,
  }) async {
    try {
      await Posthog().capture(eventName: eventName, properties: properties);
    } catch (e, st) {
      // Swallow: analytics must never crash the app.
      _log.error('captureEvent failed', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> captureScreen(String screenName) async {
    try {
      await Posthog().screen(screenName: screenName);
    } catch (e, st) {
      _log.error('captureScreen failed', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> reset() async {
    try {
      await Posthog().reset();
    } catch (e, st) {
      _log.error('reset failed', error: e, stackTrace: st);
    }
  }
}

/// Exposes the ABSTRACT type so consumers never depend on PostHog directly.
@Riverpod(keepAlive: true)
PostHogAnalyticsRepository analyticsRepository(Ref ref) {
  return PostHogAnalyticsRepository();
}
