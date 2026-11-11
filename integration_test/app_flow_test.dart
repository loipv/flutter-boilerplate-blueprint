import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blueprint_app/core/constants/app_constants.dart';
import 'package:blueprint_app/features/home/presentation/home_screen.dart';
import 'package:blueprint_app/features/onboarding/presentation/intro_view.dart';
import 'package:blueprint_app/features/settings/presentation/settings_screen.dart';
import 'package:blueprint_app/features/user_profile/data/firebase_user_repository.dart';

import 'helpers/emulator_harness.dart';

/// On-device app flows against the Auth and Firestore emulators.
/// Run with `make test-integration DEVICE=<id>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseApp app;
  late FirebaseAuth auth;
  late FirebaseFirestore firestore;

  setUpAll(() async {
    app = await setUpEmulators();
    auth = FirebaseAuth.instanceFor(app: app);
    firestore = FirebaseFirestore.instanceFor(app: app);
  });

  setUp(() async {
    // The device keeps the last session; drop it before wiping the emulator.
    await auth.signOut();
    await resetEmulators();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setString('locale_code', 'en');
  });

  DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      firestore.collection(AppConstants.usersCollection).doc(uid);

  /// Polls the emulator until `users/<uid>` satisfies [matches], then
  /// returns its data.
  Future<Map<String, dynamic>> waitForUserDoc(
    WidgetTester tester,
    String uid,
    bool Function(Map<String, dynamic> data) matches,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    Map<String, dynamic>? data;
    while (DateTime.now().isBefore(deadline)) {
      final snap = await userDoc(
        uid,
      ).get(const GetOptions(source: Source.server));
      data = snap.data();
      if (data != null && matches(data)) return data;
      await tester.pump(const Duration(milliseconds: 200));
    }
    fail('users/$uid never matched; last data: $data');
  }

  /// Signs in a returning user with a Firestore profile and onboarding done.
  Future<String> signInReturningUser() async {
    final credential = await auth.signInAnonymously();
    final uid = credential.user!.uid;
    await FirebaseUserRepository(
      firestore,
    ).recordLogin(uid, signInProvider: 'anonymous');
    final snap = await userDoc(
      uid,
    ).get(const GetOptions(source: Source.server));
    expect(snap.exists, isTrue, reason: 'recordLogin should create the doc');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingCompleteKey, true);
    return uid;
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.text('Profile'));
    await pumpUntilFound(tester, find.byTooltip('Settings'));
    await tester.tap(find.byTooltip('Settings'));
    await pumpUntilFound(tester, find.text('Haptic feedback'));
  }

  group('App flow on the emulator', () {
    testWidgets(
      'Given a returning user on Home, When haptics is turned off in Settings, Then Firestore stores preferences as a nested map',
      (tester) async {
        final uid = await signInReturningUser();

        await pumpTestApp(tester, app);
        await pumpUntilFound(tester, find.byType(HomeScreen));
        expect(find.byType(HomeScreen), findsOneWidget);

        await openSettings(tester);
        final haptics = find.widgetWithText(SwitchListTile, 'Haptic feedback');
        expect(tester.widget<SwitchListTile>(haptics).value, isTrue);
        await tester.tap(haptics);

        final data = await waitForUserDoc(tester, uid, (d) {
          final prefs = d['preferences'];
          return prefs is Map && prefs['hapticsEnabled'] == false;
        });
        // savePreferences must write a nested map; a dotted key such as
        // `preferences.hapticsEnabled` would be stored literally.
        expect(data['preferences'], isA<Map<String, dynamic>>());
        expect(
          (data['preferences'] as Map<String, dynamic>)['hapticsEnabled'],
          isFalse,
        );
        expect(data.keys.where((k) => k.contains('.')), isEmpty);
      },
    );

    testWidgets(
      'Given a returning user on Home, When they sign out from Settings, Then the onboarding intro is shown',
      (tester) async {
        await signInReturningUser();

        await pumpTestApp(tester, app);
        await pumpUntilFound(tester, find.byType(HomeScreen));
        await openSettings(tester);

        // Profile (under Settings) has its own "Sign out" tile.
        final signOutTile = find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.widgetWithText(ListTile, 'Sign out'),
        );
        await tester.ensureVisible(signOutTile);
        await tester.pump();
        await tester.tap(signOutTile);
        await pumpUntilFound(
          tester,
          find.widgetWithText(FilledButton, 'Sign out'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));

        await pumpUntilFound(tester, find.byType(IntroView));
        expect(find.byType(IntroView), findsOneWidget);
        expect(auth.currentUser, isNull);
      },
    );

    // BEGIN_ANON
    testWidgets(
      'Given a fresh start, When the guest completes onboarding, Then Home is shown and users/<uid> exists',
      (tester) async {
        await pumpTestApp(tester, app);

        await pumpUntilFound(tester, find.text('Get Started'));
        await tester.tap(find.text('Get Started'));
        await pumpUntilFound(tester, find.text('Confirm'));
        await tester.tap(find.text('Confirm'));
        // The button turns into "Continue as Guest" once the launch-time
        // anonymous sign-in has landed.
        await pumpUntilFound(tester, find.text('Continue as Guest'));
        await tester.tap(find.text('Continue as Guest'));
        await pumpUntilFound(
          tester,
          find.widgetWithText(FilledButton, 'Continue'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));

        await pumpUntilFound(tester, find.byType(HomeScreen));
        expect(find.byType(HomeScreen), findsOneWidget);

        final uid = auth.currentUser!.uid;
        expect(auth.currentUser!.isAnonymous, isTrue);
        final data = await waitForUserDoc(
          tester,
          uid,
          (d) => d['onboardingCompleted'] == true,
        );
        expect(data['signInProvider'], 'anonymous');
      },
    );
    // END_ANON
  });
}
