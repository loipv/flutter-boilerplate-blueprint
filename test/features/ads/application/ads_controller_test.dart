import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blueprint_app/core/data/firebase_remote_config_repository.dart';
import 'package:blueprint_app/core/domain/config_keys.dart';
import 'package:blueprint_app/features/ads/application/ad_frequency_cap.dart';
import 'package:blueprint_app/features/ads/application/ad_free_provider.dart';
import 'package:blueprint_app/features/ads/application/ads_consent_controller.dart';
import 'package:blueprint_app/features/ads/application/ads_controller.dart';
import 'package:blueprint_app/features/ads/application/ads_settings.dart';
import 'package:blueprint_app/features/ads/data/google_mobile_ads_repository.dart';
import 'package:blueprint_app/features/ads/domain/ad_format.dart';
import 'package:blueprint_app/features/ads/domain/ad_unit_ids.dart';
import 'package:blueprint_app/features/ads/domain/ads_repository.dart';
import 'package:blueprint_app/features/ads/domain/rewarded_outcome.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/mocks.dart';

void main() {
  late MockAdsRepository repository;
  late DateTime now;
  late Set<AdFormat> enabled;
  late Set<AdFormat> withUnitId;
  late int intervalSeconds;
  late AdsController controller;

  setUpAll(() => registerFallbackValue(AdFormat.banner));

  setUp(() {
    repository = MockAdsRepository();
    now = DateTime(2026);
    enabled = {...AdFormat.values};
    withUnitId = {...AdFormat.values};
    intervalSeconds = 90;
    controller = AdsController(
      repository: repository,
      isEnabled: (f) => enabled.contains(f),
      unitId: (f) => withUnitId.contains(f) ? 'unit-${f.name}' : null,
      cap: AdFrequencyCap(
        minInterval: () => Duration(seconds: intervalSeconds),
        now: () => now,
      ),
    );
    when(() => repository.showInterstitial()).thenAnswer((_) async => true);
    when(() => repository.showAppOpen()).thenAnswer((_) async => true);
    when(
      () => repository.showRewarded(),
    ).thenAnswer((_) async => const RewardEarned(1, 'coin'));
    when(
      () => repository.preload(any(), adUnitId: any(named: 'adUnitId')),
    ).thenAnswer((_) async {});
  });

  test('Given interstitial disabled, When shown, Then false and the '
      'repository is not called', () async {
    enabled.remove(AdFormat.interstitial);

    expect(await controller.maybeShowInterstitial(), isFalse);

    verifyZeroInteractions(repository);
  });

  test('Given a shown interstitial, When asked again at once, Then the cap '
      'returns false', () async {
    expect(await controller.maybeShowInterstitial(), isTrue);
    expect(await controller.maybeShowInterstitial(), isFalse);

    verify(() => repository.showInterstitial()).called(1);
  });

  test('Given the repository returns false, When shown, Then false, no cap '
      'recorded and the format is preloaded', () async {
    when(() => repository.showInterstitial()).thenAnswer((_) async => false);

    expect(await controller.maybeShowInterstitial(), isFalse);
    expect(await controller.maybeShowInterstitial(), isFalse);

    verify(() => repository.showInterstitial()).called(2);
    verify(
      () => repository.preload(
        AdFormat.interstitial,
        adUnitId: 'unit-interstitial',
      ),
    ).called(2);
  });

  test('Given the repository throws, When shown, Then false, the flag resets '
      'and the next call reaches the repository', () async {
    when(() => repository.showInterstitial()).thenThrow(StateError('boom'));

    expect(await controller.maybeShowInterstitial(), isFalse);

    verify(
      () => repository.preload(
        AdFormat.interstitial,
        adUnitId: 'unit-interstitial',
      ),
    ).called(1);

    when(() => repository.showInterstitial()).thenAnswer((_) async => true);
    expect(await controller.maybeShowInterstitial(), isTrue);
  });

  test('Given a rewarded that throws, When shown, Then RewardUnavailable and '
      'the flag resets', () async {
    when(() => repository.showRewarded()).thenThrow(StateError('boom'));

    expect(await controller.showRewarded(), isA<RewardUnavailable>());

    verify(
      () => repository.preload(AdFormat.rewarded, adUnitId: 'unit-rewarded'),
    ).called(1);

    when(
      () => repository.showRewarded(),
    ).thenAnswer((_) async => const RewardDismissed());
    expect(await controller.showRewarded(), isA<RewardDismissed>());
  });

  test('Given a preload that throws, When shown returns false, Then the '
      'controller still returns false', () async {
    when(() => repository.showInterstitial()).thenAnswer((_) async => false);
    when(
      () => repository.preload(any(), adUnitId: any(named: 'adUnitId')),
    ).thenThrow(StateError('boom'));

    expect(await controller.maybeShowInterstitial(), isFalse);
  });

  test('Given an interstitial just closed, When rewarded is shown, Then the '
      'cap is ignored', () async {
    await controller.maybeShowInterstitial();

    expect(await controller.showRewarded(), isA<RewardEarned>());
  });

  test('Given rewarded disabled, When shown, Then RewardUnavailable', () async {
    enabled.remove(AdFormat.rewarded);

    expect(await controller.showRewarded(), isA<RewardUnavailable>());
    verifyNever(() => repository.showRewarded());
  });

  test('Given rewarded unavailable, When shown, Then it preloads rewarded '
      'and does not record the cap', () async {
    when(
      () => repository.showRewarded(),
    ).thenAnswer((_) async => const RewardUnavailable());

    expect(await controller.showRewarded(), isA<RewardUnavailable>());
    expect(await controller.maybeShowInterstitial(), isTrue);

    verify(
      () => repository.preload(AdFormat.rewarded, adUnitId: 'unit-rewarded'),
    ).called(1);
  });

  test('Given an interstitial pending, When app open is requested, Then '
      'false and showAppOpen is never called', () async {
    final pending = Completer<bool>();
    when(() => repository.showInterstitial()).thenAnswer((_) => pending.future);

    final first = controller.maybeShowInterstitial();
    expect(await controller.maybeShowAppOpen(), isFalse);
    verifyNever(() => repository.showAppOpen());

    pending.complete(true);
    expect(await first, isTrue);
  });

  test('Given a rewarded closed 3s ago and interval 0, When app open is '
      'requested, Then false; at 6s, true', () async {
    intervalSeconds = 0;
    await controller.showRewarded();

    now = now.add(const Duration(seconds: 3));
    expect(await controller.maybeShowAppOpen(), isFalse);

    now = now.add(const Duration(seconds: 3));
    expect(await controller.maybeShowAppOpen(), isTrue);
  });

  test('Given app open disabled, When requested, Then false', () async {
    enabled.remove(AdFormat.appOpen);

    expect(await controller.maybeShowAppOpen(), isFalse);
    verifyNever(() => repository.showAppOpen());
  });

  test('Given a failing app open, When requested, Then false and preload '
      'is called', () async {
    when(() => repository.showAppOpen()).thenAnswer((_) async => false);

    expect(await controller.maybeShowAppOpen(), isFalse);

    verify(
      () => repository.preload(AdFormat.appOpen, adUnitId: 'unit-appOpen'),
    ).called(1);
  });

  test('Given some formats disabled or without a unit ID, When '
      'preloadEnabled, Then only the others are preloaded', () async {
    enabled.remove(AdFormat.interstitial);
    withUnitId.remove(AdFormat.appOpen);

    controller.preloadEnabled();
    await Future<void>.delayed(Duration.zero);

    verify(
      () => repository.preload(AdFormat.rewarded, adUnitId: 'unit-rewarded'),
    ).called(1);
    verifyNever(
      () => repository.preload(
        AdFormat.interstitial,
        adUnitId: any(named: 'adUnitId'),
      ),
    );
    verifyNever(
      () => repository.preload(
        AdFormat.appOpen,
        adUnitId: any(named: 'adUnitId'),
      ),
    );
  });

  test('Given banner enabled, When loadBanner, Then the repository gets the '
      'banner unit ID and width, and the handle is returned', () async {
    final handle = FakeAdBannerHandle();
    when(
      () => repository.loadBanner(
        adUnitId: any(named: 'adUnitId'),
        width: any(named: 'width'),
      ),
    ).thenAnswer((_) async => handle);

    expect(await controller.loadBanner(width: 320), same(handle));

    verify(
      () => repository.loadBanner(adUnitId: 'unit-banner', width: 320),
    ).called(1);
  });

  test('Given banner disabled, When loadBanner, Then null and the '
      'repository is not called', () async {
    enabled.remove(AdFormat.banner);

    expect(await controller.loadBanner(width: 320), isNull);

    verifyZeroInteractions(repository);
  });

  test('Given no banner unit ID, When loadBanner, Then null and the '
      'repository is not called', () async {
    withUnitId.remove(AdFormat.banner);

    expect(await controller.loadBanner(width: 320), isNull);

    verifyZeroInteractions(repository);
  });

  test('Given the repository throws, When loadBanner, Then null', () async {
    when(
      () => repository.loadBanner(
        adUnitId: any(named: 'adUnitId'),
        width: any(named: 'width'),
      ),
    ).thenThrow(StateError('load failed'));

    expect(await controller.loadBanner(width: 320), isNull);
  });

  group('adsControllerProvider', () {
    const settings = AdsSettings(
      enabled: true,
      useLiveIds: false,
      platform: AdPlatform.android,
      requestEeaDebugGeography: false,
      unitIds: AdUnitIds({}),
    );

    ProviderContainer makeContainer(
      FakeRemoteConfigRepository config,
      AdsConsent consent,
    ) {
      when(
        () => repository.initialize(
          debugGeographyEea: any(named: 'debugGeographyEea'),
        ),
      ).thenAnswer((_) async => consent);
      final container = ProviderContainer(
        overrides: [
          adsSettingsProvider.overrideWithValue(settings),
          adFreeProvider.overrideWithValue(false),
          adsRepositoryProvider.overrideWithValue(repository),
          remoteConfigRepositoryProvider.overrideWithValue(config),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('Given consent granted, When the controller is read, Then enabled '
        'formats are preloaded', () async {
      final config = FakeRemoteConfigRepository();
      addTearDown(config.dispose);
      final container = makeContainer(config, (
        canRequestAds: true,
        privacyOptionsRequired: false,
      ));

      container.read(adsControllerProvider);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      for (final format in [
        AdFormat.interstitial,
        AdFormat.rewarded,
        AdFormat.appOpen,
      ]) {
        verify(
          () => repository.preload(format, adUnitId: any(named: 'adUnitId')),
        ).called(1);
      }
    });

    test('Given the master key off at launch, When it flips on mid-session, '
        'Then initialize and preload are never called', () async {
      final config = FakeRemoteConfigRepository(
        values: {ConfigKeys.adsEnabled.key: false},
      );
      addTearDown(config.dispose);
      makeContainer(config, (
        canRequestAds: true,
        privacyOptionsRequired: false,
      )).listen(adsControllerProvider, (_, _) {});
      await pumpEventQueue();

      config.update({ConfigKeys.adsEnabled.key: true});
      await pumpEventQueue();

      verifyNever(
        () => repository.initialize(
          debugGeographyEea: any(named: 'debugGeographyEea'),
        ),
      );
      verifyNever(
        () => repository.preload(any(), adUnitId: any(named: 'adUnitId')),
      );
    });

    test('Given consent first denied, When privacy options grant it, Then '
        'each enabled format is preloaded exactly once', () async {
      final config = FakeRemoteConfigRepository();
      addTearDown(config.dispose);
      final container = makeContainer(config, noAdsConsent);
      when(() => repository.showPrivacyOptions()).thenAnswer(
        (_) async => (canRequestAds: true, privacyOptionsRequired: true),
      );
      container.listen(adsControllerProvider, (_, _) {});
      await pumpEventQueue();
      verifyNever(
        () => repository.preload(any(), adUnitId: any(named: 'adUnitId')),
      );

      await container
          .read(adsConsentControllerProvider.notifier)
          .showPrivacyOptions();
      await pumpEventQueue();

      for (final format in [
        AdFormat.interstitial,
        AdFormat.rewarded,
        AdFormat.appOpen,
      ]) {
        verify(
          () => repository.preload(format, adUnitId: any(named: 'adUnitId')),
        ).called(1);
      }
    });

    test('Given consent denied, When the controller is read, Then nothing is '
        'preloaded', () async {
      final config = FakeRemoteConfigRepository();
      addTearDown(config.dispose);
      final container = makeContainer(config, noAdsConsent);

      container.read(adsControllerProvider);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      verifyNever(
        () => repository.preload(any(), adUnitId: any(named: 'adUnitId')),
      );
    });

    test('Given Remote Config interval 0, When two interstitials are shown, '
        'Then both reach the repository', () async {
      final config = FakeRemoteConfigRepository(
        values: {ConfigKeys.adsFullScreenMinIntervalSeconds.key: 0},
      );
      addTearDown(config.dispose);
      final container = makeContainer(config, (
        canRequestAds: true,
        privacyOptionsRequired: false,
      ));
      final provided = container.read(adsControllerProvider);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(await provided.maybeShowInterstitial(), isTrue);
      expect(await provided.maybeShowInterstitial(), isTrue);
    });

    test('Given the default interval, When two interstitials are shown, '
        'Then the second is capped', () async {
      final config = FakeRemoteConfigRepository();
      addTearDown(config.dispose);
      final container = makeContainer(config, (
        canRequestAds: true,
        privacyOptionsRequired: false,
      ));
      final provided = container.read(adsControllerProvider);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(await provided.maybeShowInterstitial(), isTrue);
      expect(await provided.maybeShowInterstitial(), isFalse);
    });
  });
}
