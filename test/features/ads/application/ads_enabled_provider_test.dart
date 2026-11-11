import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blueprint_app/core/data/firebase_remote_config_repository.dart';
import 'package:blueprint_app/features/ads/application/ad_free_provider.dart';
import 'package:blueprint_app/features/ads/application/ads_consent_controller.dart';
import 'package:blueprint_app/features/ads/application/ads_enabled_provider.dart';
import 'package:blueprint_app/features/ads/application/ads_settings.dart';
import 'package:blueprint_app/features/ads/data/google_mobile_ads_repository.dart';
import 'package:blueprint_app/features/ads/domain/ad_format.dart';
import 'package:blueprint_app/features/ads/domain/ad_unit_ids.dart';
import 'package:blueprint_app/features/ads/domain/ads_repository.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/mocks.dart';

const _enabled = AdsSettings(
  enabled: true,
  useLiveIds: false,
  platform: AdPlatform.android,
  requestEeaDebugGeography: false,
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
    when(
      () => repository.initialize(
        debugGeographyEea: any(named: 'debugGeographyEea'),
      ),
    ).thenAnswer((_) async => _granted);
  });

  ProviderContainer makeContainer({
    AdsSettings settings = _enabled,
    bool adFree = false,
    AdsConsent consent = _granted,
  }) {
    when(
      () => repository.initialize(
        debugGeographyEea: any(named: 'debugGeographyEea'),
      ),
    ).thenAnswer((_) async => consent);
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

  /// Reads adsEnabled once consent has resolved.
  Future<bool> read(ProviderContainer container, AdFormat format) async {
    container.listen(adsEnabledProvider(format), (_, _) {});
    await container
        .read(adsConsentControllerProvider.future)
        .catchError((_) => noAdsConsent);
    await Future<void>.delayed(Duration.zero);
    return container.read(adsEnabledProvider(format));
  }

  test('Given every level on, When read, Then every format is true', () async {
    final container = makeContainer();

    for (final format in AdFormat.values) {
      expect(await read(container, format), isTrue, reason: '$format');
    }
  });

  test('Given settings disabled, When read, Then false and initialize is '
      'never called', () async {
    final container = makeContainer(settings: AdsSettings.disabled);

    for (final format in AdFormat.values) {
      expect(await read(container, format), isFalse);
    }
    verifyNever(
      () => repository.initialize(
        debugGeographyEea: any(named: 'debugGeographyEea'),
      ),
    );
  });

  test('Given master key off, When read, Then false and initialize is '
      'never called', () async {
    config.values = {'ads_enabled': false};
    final container = makeContainer();

    container.listen(adsEnabledProvider(AdFormat.banner), (_, _) {});
    await Future<void>.delayed(Duration.zero);

    expect(container.read(adsEnabledProvider(AdFormat.banner)), isFalse);
    verifyNever(
      () => repository.initialize(
        debugGeographyEea: any(named: 'debugGeographyEea'),
      ),
    );
  });

  test('Given adFree, When read, Then false and initialize is never '
      'called', () async {
    final container = makeContainer(adFree: true);

    container.listen(adsEnabledProvider(AdFormat.banner), (_, _) {});
    await Future<void>.delayed(Duration.zero);

    expect(container.read(adsEnabledProvider(AdFormat.banner)), isFalse);
    verifyNever(
      () => repository.initialize(
        debugGeographyEea: any(named: 'debugGeographyEea'),
      ),
    );
  });

  const formatKeys = {
    AdFormat.banner: 'ads_banner_enabled',
    AdFormat.interstitial: 'ads_interstitial_enabled',
    AdFormat.rewarded: 'ads_rewarded_enabled',
    AdFormat.appOpen: 'ads_app_open_enabled',
  };

  for (final entry in formatKeys.entries) {
    test('Given ${entry.value} off, When read, Then only ${entry.key} is '
        'false', () async {
      config.values = {entry.value: false};
      final container = makeContainer();

      for (final format in AdFormat.values) {
        expect(await read(container, format), format != entry.key);
      }
    });
  }

  test('Given master key off, When read, Then every format is false', () async {
    config.values = {'ads_enabled': false};
    final container = makeContainer();

    for (final format in AdFormat.values) {
      expect(await read(container, format), isFalse);
    }
  });

  test('Given canRequestAds false, When read, Then false', () async {
    final container = makeContainer(consent: noAdsConsent);

    expect(await read(container, AdFormat.banner), isFalse);
  });

  test('Given no unit ID for the format, When read, Then false', () async {
    final container = makeContainer(
      settings: const AdsSettings(
        enabled: true,
        useLiveIds: true,
        platform: AdPlatform.android,
        requestEeaDebugGeography: false,
        unitIds: AdUnitIds({}),
      ),
    );

    expect(await read(container, AdFormat.banner), isFalse);
  });

  test('Given banner enabled, When ads_banner_enabled updates to false, '
      'Then banner becomes false and interstitial stays true', () async {
    final container = makeContainer();
    expect(await read(container, AdFormat.banner), isTrue);
    expect(await read(container, AdFormat.interstitial), isTrue);

    config.update({'ads_banner_enabled': false});
    await pumpEventQueue();

    expect(container.read(adsEnabledProvider(AdFormat.banner)), isFalse);
    expect(container.read(adsEnabledProvider(AdFormat.interstitial)), isTrue);
  });

  test('Given consent changes to canRequestAds false via '
      'showPrivacyOptions, Then every format is false', () async {
    when(
      () => repository.showPrivacyOptions(),
    ).thenAnswer((_) async => noAdsConsent);
    final container = makeContainer();
    for (final format in AdFormat.values) {
      expect(await read(container, format), isTrue);
    }

    await container
        .read(adsConsentControllerProvider.notifier)
        .showPrivacyOptions();
    await pumpEventQueue();

    for (final format in AdFormat.values) {
      expect(container.read(adsEnabledProvider(format)), isFalse);
    }
  });
}
