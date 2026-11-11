import 'dart:async';

// BEGIN_POSTHOG
import 'package:flutter/services.dart';
// END_POSTHOG
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global bootstrap for every test file run by `flutter test`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // BEGIN_POSTHOG
  // PosthogObserver (in the router) sends `$screen` events over this channel.
  // Answer them with null so widget tests that pump the router never hit
  // MissingPluginException. Registered per test in case a test replaces or
  // clears mock handlers.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('posthog_flutter'),
          (_) async => null,
        );
  });
  // END_POSTHOG

  SharedPreferences.setMockInitialValues({});
  await testMain();
}
