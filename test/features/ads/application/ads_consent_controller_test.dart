import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blueprint_app/core/data/firebase_remote_config_repository.dart';
import 'package:blueprint_app/core/domain/config_keys.dart';
import 'package:blueprint_app/features/ads/application/ad_free_provider.dart';
import 'package:blueprint_app/features/ads/application/ads_consent_controller.dart';
import 'package:blueprint_app/features/ads/application/ads_settings.dart';
import 'package:blueprint_app/features/ads/data/google_mobile_ads_repository.dart';
import 'package:blueprint_app/features/ads/domain/ad_unit_ids.dart';
import 'package:blueprint_app/features/ads/domain/ads_repository.dart';

import '../../../helpers/fakes.dart';
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
  late FakeRemoteConfigRepository config;

  setUp(() {
    repository = MockAdsRepository();
    config = FakeRemoteConfigRepository();
    addTearDown(config.dispose);
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
        remoteConfigRepositoryProvider.overrideWithValue(config),
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

  test('Given the master ads_enabled key off, When built, Then noAdsConsent '
      'and initialize is never called', () async {
    config.values = {ConfigKeys.adsEnabled.key: false};
    final container = makeContainer();

    final consent = await container.read(adsConsentControllerProvider.future);

    expect(consent, noAdsConsent);
    verifyNever(
      () => repository.initialize(
        debugGeographyEea: any(named: 'debugGeographyEea'),
      ),
    );
  });

  test(
    'Given the master key off at launch, When it flips on mid-session, '
    'Then consent stays noAdsConsent and initialize is never called',
    () async {
      config.values = {ConfigKeys.adsEnabled.key: false};
      final container = makeContainer();
      container.listen(adsConsentControllerProvider, (_, _) {});
      await container.read(adsConsentControllerProvider.future);

      config.update({ConfigKeys.adsEnabled.key: true});
      await pumpEventQueue();
      final consent = await container.read(adsConsentControllerProvider.future);

      expect(consent, noAdsConsent);
      verifyNever(
        () => repository.initialize(
          debugGeographyEea: any(named: 'debugGeographyEea'),
        ),
      );
    },
  );

  test('Given the master key on at launch, When it flips off mid-session, '
      'Then consent is kept and initialize ran once', () async {
    when(
      () => repository.initialize(debugGeographyEea: true),
    ).thenAnswer((_) async => _granted);
    final container = makeContainer();
    container.listen(adsConsentControllerProvider, (_, _) {});
    await container.read(adsConsentControllerProvider.future);

    config.update({ConfigKeys.adsEnabled.key: false});
    await pumpEventQueue();
    final consent = await container.read(adsConsentControllerProvider.future);

    expect(consent, _granted);
    verify(() => repository.initialize(debugGeographyEea: true)).called(1);
  });

  test('Given initialize throws, When built, Then noAdsConsent and the flow '
      'is not retried', () async {
    when(
      () => repository.initialize(debugGeographyEea: true),
    ).thenThrow(StateError('consent failed'));
    final container = makeContainer();
    container.listen(adsConsentControllerProvider, (_, _) {});

    final consent = await container.read(adsConsentControllerProvider.future);
    await pumpEventQueue();

    expect(consent, noAdsConsent);
    expect(container.read(adsConsentControllerProvider).hasError, isFalse);
    verify(() => repository.initialize(debugGeographyEea: true)).called(1);
  });

  test(
    'Given adFree flips false to true to false, When rebuilt, Then '
    'noAdsConsent while true and initialize runs again on the way back',
    () async {
      when(
        () => repository.initialize(debugGeographyEea: true),
      ).thenAnswer((_) async => _granted);
      final adFree = StateProvider<bool>((ref) => false);
      final container = ProviderContainer(
        overrides: [
          adsSettingsProvider.overrideWithValue(_enabled),
          adFreeProvider.overrideWith((ref) => ref.watch(adFree)),
          adsRepositoryProvider.overrideWithValue(repository),
          remoteConfigRepositoryProvider.overrideWithValue(config),
        ],
      );
      addTearDown(container.dispose);
      container.listen(adsConsentControllerProvider, (_, _) {});
      expect(
        await container.read(adsConsentControllerProvider.future),
        _granted,
      );

      container.read(adFree.notifier).state = true;
      expect(
        await container.read(adsConsentControllerProvider.future),
        noAdsConsent,
      );
      verify(() => repository.initialize(debugGeographyEea: true)).called(1);

      container.read(adFree.notifier).state = false;
      expect(
        await container.read(adsConsentControllerProvider.future),
        _granted,
      );
      verify(() => repository.initialize(debugGeographyEea: true)).called(1);
    },
  );

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
