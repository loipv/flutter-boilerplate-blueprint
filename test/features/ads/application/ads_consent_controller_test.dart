import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blueprint_app/features/ads/application/ad_free_provider.dart';
import 'package:blueprint_app/features/ads/application/ads_consent_controller.dart';
import 'package:blueprint_app/features/ads/application/ads_settings.dart';
import 'package:blueprint_app/features/ads/data/google_mobile_ads_repository.dart';
import 'package:blueprint_app/features/ads/domain/ad_unit_ids.dart';
import 'package:blueprint_app/features/ads/domain/ads_repository.dart';

import '../../../helpers/mocks.dart';

const _enabled = AdsSettings(
  enabled: true,
  useLiveIds: false,
  platform: AdPlatform.android,
  requestEeaDebugGeography: true,
  unitIds: AdUnitIds({}),
);

const _granted = (canRequestAds: true, privacyOptionsRequired: true);

void main() {
  late MockAdsRepository repository;

  setUp(() {
    repository = MockAdsRepository();
  });

  ProviderContainer makeContainer({
    AdsSettings settings = _enabled,
    bool adFree = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        adsSettingsProvider.overrideWithValue(settings),
        adFreeProvider.overrideWithValue(adFree),
        adsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('Given settings disabled, When built, Then noAdsConsent and '
      'initialize is never called', () async {
    final container = makeContainer(settings: AdsSettings.disabled);

    final consent = await container.read(adsConsentControllerProvider.future);

    expect(consent, noAdsConsent);
    verifyNever(
      () => repository.initialize(
        debugGeographyEea: any(named: 'debugGeographyEea'),
      ),
    );
  });

  test('Given adFree, When built, Then noAdsConsent and initialize is '
      'never called', () async {
    final container = makeContainer(adFree: true);

    final consent = await container.read(adsConsentControllerProvider.future);

    expect(consent, noAdsConsent);
    verifyNever(
      () => repository.initialize(
        debugGeographyEea: any(named: 'debugGeographyEea'),
      ),
    );
  });

  test('Given enabled, When built, Then returns repository consent and '
      'forwards debugGeographyEea', () async {
    when(
      () => repository.initialize(debugGeographyEea: true),
    ).thenAnswer((_) async => _granted);
    final container = makeContainer();

    final consent = await container.read(adsConsentControllerProvider.future);

    expect(consent, _granted);
    verify(() => repository.initialize(debugGeographyEea: true)).called(1);
  });

  test('Given built, When showPrivacyOptions, Then state is the new '
      'consent', () async {
    when(
      () => repository.initialize(debugGeographyEea: true),
    ).thenAnswer((_) async => _granted);
    when(
      () => repository.showPrivacyOptions(),
    ).thenAnswer((_) async => noAdsConsent);
    final container = makeContainer();
    await container.read(adsConsentControllerProvider.future);

    await container
        .read(adsConsentControllerProvider.notifier)
        .showPrivacyOptions();

    expect(container.read(adsConsentControllerProvider).value, noAdsConsent);
  });
}
