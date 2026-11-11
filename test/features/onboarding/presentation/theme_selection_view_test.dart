import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blueprint_app/features/onboarding/presentation/theme_selection_view.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Given locale vi, When ThemeSelectionView is pumped, '
      'Then the Vietnamese headline is shown', (tester) async {
    await pumpApp(
      tester,
      const ThemeSelectionView(),
      locale: const Locale('vi'),
    );

    expect(find.text('Chọn phong cách của bạn'), findsOneWidget);
  });

  testWidgets('Given locale vi and a 320x640 surface, When pumped, '
      'Then no overflow is reported', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(
      tester,
      const ThemeSelectionView(),
      locale: const Locale('vi'),
    );

    expect(tester.takeException(), isNull);
  });
}
