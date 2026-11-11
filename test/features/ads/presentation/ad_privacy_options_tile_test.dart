import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blueprint_app/features/ads/application/ads_settings.dart';
import 'package:blueprint_app/features/ads/data/google_mobile_ads_repository.dart';
import 'package:blueprint_app/features/ads/domain/ad_unit_ids.dart';
import 'package:blueprint_app/features/ads/domain/ads_repository.dart';
import 'package:blueprint_app/features/ads/presentation/ad_privacy_options_tile.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/pump_app.dart';

const _settings = AdsSettings(
  enabled: true,
  useLiveIds: false,
  platform: AdPlatform.android,
  requestEeaDebugGeography: false,
  unitIds: AdUnitIds({}),
);

void main() {
  late MockAdsRepository repository;

  setUp(() {
    repository = MockAdsRepository();
  });

  Future<void> pump(WidgetTester tester, AdsConsent consent) {
    when(
      () => repository.initialize(
        debugGeographyEea: any(named: 'debugGeographyEea'),
      ),
    ).thenAnswer((_) async => consent);
    when(
      () => repository.showPrivacyOptions(),
    ).thenAnswer((_) async => consent);
    return pumpApp(
      tester,
      const AdPrivacyOptionsTile(header: Text('Ads header')),
      overrides: [
        adsSettingsProvider.overrideWithValue(_settings),
        adsRepositoryProvider.overrideWithValue(repository),
      ],
    );
  }

  testWidgets('Given privacy options not required, When built, Then no tile '
      'shows', (tester) async {
    await pump(tester, (canRequestAds: true, privacyOptionsRequired: false));

    expect(find.text('Privacy options'), findsNothing);
    expect(find.text('Ads header'), findsNothing);
  });

  testWidgets('Given privacy options required, When tapped, Then header and '
      'tile show and showPrivacyOptions is called', (tester) async {
    await pump(tester, (canRequestAds: true, privacyOptionsRequired: true));

    expect(find.text('Ads header'), findsOneWidget);
    expect(find.text('Manage ad consent'), findsOneWidget);
    await tester.tap(find.text('Privacy options'));
    await tester.pumpAndSettle();

    verify(() => repository.showPrivacyOptions()).called(1);
  });
}
