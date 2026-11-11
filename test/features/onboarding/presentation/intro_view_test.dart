import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/features/onboarding/presentation/intro_view.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('Given locale vi, When IntroView is pumped, '
      'Then the Vietnamese headline and CTA are shown', (tester) async {
    await pumpApp(tester, const IntroView(), locale: const Locale('vi'));

    expect(find.text('Chào mừng đến với\nBlueprint App'), findsOneWidget);
    expect(find.text('Bắt đầu'), findsOneWidget);
  });
}
