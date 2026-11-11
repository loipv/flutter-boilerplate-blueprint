import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blueprint_app/features/auth/data/firebase_auth_repository.dart';
import 'package:blueprint_app/features/auth/domain/user_entity.dart';
import 'package:blueprint_app/features/auth/domain/user_preferences.dart';
import 'package:blueprint_app/features/settings/presentation/settings_screen.dart';
import 'package:blueprint_app/features/user_profile/data/firebase_user_repository.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/pump_app.dart';

void main() {
  late MockAuthRepository authRepo;
  late MockUserRepository userRepo;

  const user = UserEntity(id: 'u1');

  setUpAll(() {
    registerFallbackValue(const UserPreferences());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authRepo = MockAuthRepository();
    userRepo = MockUserRepository();
    when(
      () => authRepo.authStateChanges(),
    ).thenAnswer((_) => Stream.value(user));
    when(
      () => userRepo.getUserStream(any()),
    ).thenAnswer((_) => Stream.value(user));
    when(() => userRepo.savePreferences(any(), any())).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, {Locale? locale}) => pumpApp(
    tester,
    const SettingsScreen(),
    locale: locale,
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      userRepositoryProvider.overrideWithValue(userRepo),
    ],
  );

  Future<void> selectVietnamese(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButton<Locale?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếng Việt').last);
    await tester.pumpAndSettle();
  }

  group('SettingsScreen', () {
    testWidgets('Given English, When pumped, Then the Language tile shows '
        'System', (tester) async {
      await pump(tester);

      expect(find.text('Language'), findsOneWidget);
      final dropdown = find.byType(DropdownButton<Locale?>);
      expect(
        find.descendant(of: dropdown, matching: find.text('System')),
        findsOneWidget,
      );
    });

    testWidgets("Given the Language dropdown, When 'Tiếng Việt' is selected, "
        "Then 'Ngôn ngữ' is shown and the choice is persisted", (tester) async {
      await pump(tester);

      await selectVietnamese(tester);

      expect(find.text('Ngôn ngữ'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale_code'), 'vi');
      verify(
        () => userRepo.savePreferences(
          'u1',
          const UserPreferences(languageCode: 'vi'),
        ),
      ).called(1);
    });

    testWidgets("Given savePreferences throws, When 'Tiếng Việt' is "
        "selected, Then 'Ngôn ngữ' is still shown and no exception is "
        'reported', (tester) async {
      when(
        () => userRepo.savePreferences(any(), any()),
      ).thenThrow(StateError('boom'));
      await pump(tester);

      await selectVietnamese(tester);

      expect(find.text('Ngôn ngữ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Given locale vi and a 320x640 surface, When pumped, Then no '
        'overflow is reported', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pump(tester, locale: const Locale('vi'));

      expect(find.text('Ngôn ngữ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
