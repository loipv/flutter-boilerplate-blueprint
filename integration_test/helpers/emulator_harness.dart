import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// BEGIN_NOTIFICATIONS
import 'package:flutter/material.dart' show TimeOfDay;
// END_NOTIFICATIONS
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
// BEGIN_NOTIFICATIONS
import 'package:shared_preferences/shared_preferences.dart';
// END_NOTIFICATIONS
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:blueprint_app/app.dart';
import 'package:blueprint_app/core/data/posthog_analytics_repository.dart';
// BEGIN_NOTIFICATIONS
import 'package:blueprint_app/core/services/notification_service.dart';
// END_NOTIFICATIONS
import 'package:blueprint_app/features/auth/data/firebase_auth_repository.dart';
import 'package:blueprint_app/features/user_profile/data/firebase_user_repository.dart';
// BEGIN_NOTIFICATIONS
import 'package:blueprint_app/l10n/generated/app_localizations.dart';
// END_NOTIFICATIONS

/// Host of the Firebase Emulator as seen from the device: `localhost` for an
/// iOS simulator, `10.0.2.2` for an Android emulator.
const emulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: 'localhost',
);

/// Offline project id: the emulator never reaches a real Firebase project.
const _projectId = 'demo-test';
const _appName = 'integration';

/// Initializes the `integration` Firebase app and points Auth and Firestore
/// at the local emulator. The default app and `main()` are never used.
Future<FirebaseApp> setUpEmulators() async {
  final app = await Firebase.initializeApp(
    name: _appName,
    options: FirebaseOptions(
      apiKey: 'demo',
      // The iOS SDK aborts on an app id whose platform segment is not `ios`.
      appId: Platform.isIOS ? '1:1:ios:1' : '1:1:android:1',
      messagingSenderId: '1',
      projectId: _projectId,
    ),
  );
  await FirebaseAuth.instanceFor(app: app).useAuthEmulator(emulatorHost, 9099);
  // No local cache: every read reflects the emulator, which tests reset.
  FirebaseFirestore.instanceFor(app: app)
    ..settings = const Settings(persistenceEnabled: false)
    ..useFirestoreEmulator(emulatorHost, 8080);
  return app;
}

/// Deletes every Auth account and Firestore document in the emulator.
Future<void> resetEmulators() async {
  await _delete(
    Uri.parse(
      'http://$emulatorHost:9099/emulator/v1/projects/$_projectId/accounts',
    ),
  );
  await _delete(
    Uri.parse(
      'http://$emulatorHost:8080/emulator/v1/projects/$_projectId'
      '/databases/(default)/documents',
    ),
  );
}

Future<void> _delete(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.deleteUrl(uri);
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode >= 300) {
      throw HttpException('DELETE returned ${response.statusCode}', uri: uri);
    }
  } finally {
    client.close();
  }
}

/// Pumps [App] wired to the emulator-backed [app] with analytics (and
/// notifications) replaced by no-ops. Callers wait for the screen they expect
/// with [pumpUntilFound].
Future<void> pumpTestApp(WidgetTester tester, FirebaseApp app) async {
  final analytics = _NoopAnalyticsRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FirebaseAuthRepository(
            FirebaseAuth.instanceFor(app: app),
            analytics,
            googleSignIn: GoogleSignIn.instance,
            fetchAppleCredential: SignInWithApple.getAppleIDCredential,
          ),
        ),
        userRepositoryProvider.overrideWithValue(
          FirebaseUserRepository(FirebaseFirestore.instanceFor(app: app)),
        ),
        analyticsRepositoryProvider.overrideWithValue(analytics),
        // BEGIN_NOTIFICATIONS
        notificationServiceProvider.overrideWithValue(
          _NoopNotificationService(),
        ),
        // END_NOTIFICATIONS
      ],
      child: const App(),
    ),
  );
}

/// Pumps frames until [finder] matches, failing after [timeout]. Real
/// emulator round trips make `pumpAndSettle` unreliable here.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out after $timeout waiting for $finder');
}

// analyticsRepositoryProvider exposes the concrete PostHog type, so the no-op
// implements it (and through it, AnalyticsRepository).
class _NoopAnalyticsRepository implements PostHogAnalyticsRepository {
  @override
  Future<void> captureEvent(
    String eventName, {
    Map<String, Object>? properties,
  }) async {}

  @override
  Future<void> captureScreen(String screenName) async {}

  @override
  Future<void> reset() async {}
}

// BEGIN_NOTIFICATIONS
class _NoopNotificationService implements NotificationService {
  @override
  Stream<String?> get onNotificationTap => const Stream<String?>.empty();

  @override
  Future<void> init() async {}

  @override
  Future<String?> refreshTimezone() async => null;

  @override
  Future<void> scheduleDailyNotification({
    required TimeOfDay time,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
    String payload = 'daily_reminder',
  }) async {}

  @override
  Future<void> rescheduleIfTimezoneChanged(
    SharedPreferences prefs,
    AppLocalizations l10n,
  ) async {}

  @override
  Future<void> cancelDailyNotification() async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<bool?> requestPermissions() async => false;
}

// END_NOTIFICATIONS
