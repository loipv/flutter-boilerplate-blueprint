import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blueprint_app/features/ads/data/google_mobile_ads_gateway.dart';
import 'package:blueprint_app/features/ads/data/google_mobile_ads_repository.dart';
import 'package:blueprint_app/features/ads/domain/ad_banner_handle.dart';
import 'package:blueprint_app/features/ads/domain/ad_format.dart';
import 'package:blueprint_app/features/ads/domain/rewarded_outcome.dart';
import 'package:blueprint_app/features/ads/domain/ads_repository.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockGoogleMobileAdsGateway gateway;
  late GoogleMobileAdsRepository repo;

  setUpAll(() => registerFallbackValue(AdFormat.interstitial));

  setUp(() {
    gateway = MockGoogleMobileAdsGateway();
    repo = GoogleMobileAdsRepository(gateway);
    when(
      () => gateway.requestConsentInfoUpdate(
        debugGeographyEea: any(named: 'debugGeographyEea'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => gateway.loadAndShowConsentFormIfRequired(),
    ).thenAnswer((_) async {});
    when(() => gateway.initializeSdk()).thenAnswer((_) async {});
    when(() => gateway.canRequestAds()).thenAnswer((_) async => true);
    when(() => gateway.privacyOptionsRequired()).thenAnswer((_) async => true);
    when(() => gateway.showPrivacyOptionsForm()).thenAnswer((_) async {});
  });

  group('initialize', () {
    test(
      'Given canRequestAds true before the form, When initialize, '
      'Then initializeSdk runs once and is not awaited behind the form',
      () async {
        final form = Completer<void>();
        when(
          () => gateway.loadAndShowConsentFormIfRequired(),
        ).thenAnswer((_) => form.future);

        final result = repo.initialize(debugGeographyEea: false);
        await pumpEventQueue();

        verify(() => gateway.initializeSdk()).called(1);
        form.complete();
        expect(await result, (
          canRequestAds: true,
          privacyOptionsRequired: true,
        ));
      },
    );

    test(
      'Given canRequestAds false before and true after the form, '
      'When initialize, Then initializeSdk runs once, after the form',
      () async {
        final form = Completer<void>();
        var calls = 0;
        when(
          () => gateway.canRequestAds(),
        ).thenAnswer((_) async => calls++ > 0);
        when(
          () => gateway.loadAndShowConsentFormIfRequired(),
        ).thenAnswer((_) => form.future);

        final result = repo.initialize(debugGeographyEea: false);
        await pumpEventQueue();
        verifyNever(() => gateway.initializeSdk());

        form.complete();
        await result;
        verify(() => gateway.initializeSdk()).called(1);
      },
    );

    test('Given canRequestAds false after the form, When initialize, '
        'Then initializeSdk is never called and consent is false', () async {
      when(() => gateway.canRequestAds()).thenAnswer((_) async => false);

      final result = await repo.initialize(debugGeographyEea: false);

      verifyNever(() => gateway.initializeSdk());
      expect(result, (canRequestAds: false, privacyOptionsRequired: true));
    });

    test('Given requestConsentInfoUpdate throws, When initialize, '
        'Then it completes, still reads canRequestAds, and returns that '
        'consent', () async {
      when(
        () => gateway.requestConsentInfoUpdate(
          debugGeographyEea: any(named: 'debugGeographyEea'),
        ),
      ).thenThrow(StateError('boom'));

      final result = await repo.initialize(debugGeographyEea: false);

      expect(result, (canRequestAds: true, privacyOptionsRequired: true));
      verify(() => gateway.canRequestAds()).called(greaterThanOrEqualTo(1));
    });

    test('Given every gateway call throws (sync and async), When initialize, '
        'Then it returns noAdsConsent and does not throw', () async {
      when(
        () => gateway.requestConsentInfoUpdate(
          debugGeographyEea: any(named: 'debugGeographyEea'),
        ),
      ).thenThrow(StateError('sync'));
      when(
        () => gateway.loadAndShowConsentFormIfRequired(),
      ).thenAnswer((_) async => throw StateError('async'));
      when(() => gateway.canRequestAds()).thenThrow(StateError('sync'));
      when(
        () => gateway.privacyOptionsRequired(),
      ).thenAnswer((_) async => throw StateError('async'));
      when(() => gateway.initializeSdk()).thenThrow(StateError('sync'));

      expect(await repo.initialize(debugGeographyEea: false), noAdsConsent);
    });

    test('Given initializeSdk throws, When initialize, Then it still '
        'returns consent', () async {
      when(
        () => gateway.initializeSdk(),
      ).thenAnswer((_) async => throw StateError('async'));

      final result = await repo.initialize(debugGeographyEea: false);

      expect(result.canRequestAds, isTrue);
    });

    test('Given initialize called twice, When both complete, '
        'Then initializeSdk ran once', () async {
      await repo.initialize(debugGeographyEea: false);
      await repo.initialize(debugGeographyEea: false);

      verify(() => gateway.initializeSdk()).called(1);
    });

    test('Given debugGeographyEea true, When initialize, '
        'Then the gateway receives debugGeographyEea: true', () async {
      await repo.initialize(debugGeographyEea: true);

      verify(
        () => gateway.requestConsentInfoUpdate(debugGeographyEea: true),
      ).called(1);
    });
  });

  group('showPrivacyOptions', () {
    test('Given showPrivacyOptionsForm throws, When showPrivacyOptions, '
        'Then it returns the consent re-read from the gateway', () async {
      when(() => gateway.showPrivacyOptionsForm()).thenThrow(StateError('x'));
      when(
        () => gateway.privacyOptionsRequired(),
      ).thenAnswer((_) async => false);

      final result = await repo.showPrivacyOptions();

      expect(result, (canRequestAds: true, privacyOptionsRequired: false));
    });
  });

  group('full-screen slots', () {
    const unit = 'unit-1';
    late MockLoadedAd ad;
    late DateTime clock;

    setUp(() {
      ad = MockLoadedAd();
      clock = DateTime(2026, 1, 1, 12);
      repo = GoogleMobileAdsRepository(gateway, now: () => clock);
      when(
        () => gateway.loadFullScreen(any(), any()),
      ).thenAnswer((_) async => ad);
      when(
        () => ad.show(),
      ).thenAnswer((_) async => const AdShowResult(shown: true));
    });

    test('Given a preloaded interstitial, When showInterstitial and the ad '
        'reports shown, Then true, and loadFullScreen is called again with '
        'the same unit ID', () async {
      await repo.preload(AdFormat.interstitial, adUnitId: unit);

      expect(await repo.showInterstitial(), isTrue);

      verify(
        () => gateway.loadFullScreen(AdFormat.interstitial, unit),
      ).called(2);
      verify(() => ad.dispose()).called(1);
    });

    test('Given nothing preloaded, When showInterstitial, '
        'Then false and no load is started', () async {
      expect(await repo.showInterstitial(), isFalse);

      verifyNever(() => gateway.loadFullScreen(any(), any()));
    });

    for (final code in [3, 0]) {
      test(
        'Given loadFullScreen throws AdLoadException($code), '
        'When preload then showInterstitial, Then no throw and false',
        () async {
          when(
            () => gateway.loadFullScreen(any(), any()),
          ).thenThrow(AdLoadException(code, 'nope'));

          await repo.preload(AdFormat.interstitial, adUnitId: unit);

          expect(await repo.showInterstitial(), isFalse);
        },
      );
    }

    test('Given loadFullScreen throws asynchronously, When preload, '
        'Then no throw', () async {
      when(
        () => gateway.loadFullScreen(any(), any()),
      ).thenAnswer((_) async => throw const AdLoadException(0, 'x'));

      await repo.preload(AdFormat.rewarded, adUnitId: unit);

      expect(await repo.showRewarded(), isA<RewardUnavailable>());
    });

    test('Given show reports shown: false, When showInterstitial, '
        'Then false and the slot is reloaded', () async {
      when(
        () => ad.show(),
      ).thenAnswer((_) async => const AdShowResult(shown: false));
      await repo.preload(AdFormat.interstitial, adUnitId: unit);

      expect(await repo.showInterstitial(), isFalse);

      verify(
        () => gateway.loadFullScreen(AdFormat.interstitial, unit),
      ).called(2);
      verify(() => ad.dispose()).called(1);
    });

    test('Given show throws PlatformException, When showInterstitial, '
        'Then false, the ad is disposed and the slot is reloaded', () async {
      when(() => ad.show()).thenThrow(PlatformException(code: 'x'));
      await repo.preload(AdFormat.interstitial, adUnitId: unit);

      expect(await repo.showInterstitial(), isFalse);

      verify(
        () => gateway.loadFullScreen(AdFormat.interstitial, unit),
      ).called(2);
      verify(() => ad.dispose()).called(1);
    });

    test('Given rewarded show throws asynchronously, When showRewarded, '
        'Then RewardUnavailable and the slot is reloaded', () async {
      when(
        () => ad.show(),
      ).thenAnswer((_) async => throw PlatformException(code: 'x'));
      await repo.preload(AdFormat.rewarded, adUnitId: unit);

      expect(await repo.showRewarded(), isA<RewardUnavailable>());

      verify(() => gateway.loadFullScreen(AdFormat.rewarded, unit)).called(2);
      verify(() => ad.dispose()).called(1);
    });

    test('Given dispose throws, When showInterstitial, '
        'Then it still returns the result', () async {
      when(() => ad.dispose()).thenThrow(StateError('x'));
      await repo.preload(AdFormat.interstitial, adUnitId: unit);

      expect(await repo.showInterstitial(), isTrue);
    });

    test('Given two preload calls before the first load completes, '
        'When both finish, Then loadFullScreen ran once', () async {
      final load = Completer<LoadedAd>();
      when(
        () => gateway.loadFullScreen(any(), any()),
      ).thenAnswer((_) => load.future);

      final a = repo.preload(AdFormat.interstitial, adUnitId: unit);
      final b = repo.preload(AdFormat.interstitial, adUnitId: unit);
      load.complete(ad);
      await Future.wait([a, b]);

      verify(
        () => gateway.loadFullScreen(AdFormat.interstitial, unit),
      ).called(1);
    });

    test('Given a filled slot, When preload, Then no new load', () async {
      await repo.preload(AdFormat.interstitial, adUnitId: unit);
      await repo.preload(AdFormat.interstitial, adUnitId: unit);

      verify(
        () => gateway.loadFullScreen(AdFormat.interstitial, unit),
      ).called(1);
    });

    test(
      'Given a rewarded ad that reports reward (5, coins), '
      'When showRewarded, Then RewardEarned with amount 5 and type coins',
      () async {
        when(() => ad.show()).thenAnswer(
          (_) async =>
              const AdShowResult(shown: true, reward: RewardEarned(5, 'coins')),
        );
        await repo.preload(AdFormat.rewarded, adUnitId: unit);

        final outcome = await repo.showRewarded();

        expect(outcome, isA<RewardEarned>());
        final earned = outcome as RewardEarned;
        expect(earned.amount, 5);
        expect(earned.type, 'coins');
      },
    );

    test('Given a rewarded ad dismissed without reward, When showRewarded, '
        'Then RewardDismissed', () async {
      await repo.preload(AdFormat.rewarded, adUnitId: unit);

      expect(await repo.showRewarded(), isA<RewardDismissed>());
    });

    test('Given nothing cached, When showRewarded, '
        'Then RewardUnavailable', () async {
      expect(await repo.showRewarded(), isA<RewardUnavailable>());
      verifyNever(() => gateway.loadFullScreen(any(), any()));
    });

    test('Given an app open ad loaded 4h 1m ago, When showAppOpen, '
        'Then false, the old ad is disposed, and the slot reloads', () async {
      await repo.preload(AdFormat.appOpen, adUnitId: unit);
      clock = clock.add(const Duration(hours: 4, minutes: 1));

      expect(await repo.showAppOpen(), isFalse);

      verifyNever(() => ad.show());
      verify(() => ad.dispose()).called(1);
      verify(() => gateway.loadFullScreen(AdFormat.appOpen, unit)).called(2);
    });

    test('Given an app open ad loaded 3h 59m ago, When showAppOpen, '
        'Then it is shown', () async {
      await repo.preload(AdFormat.appOpen, adUnitId: unit);
      clock = clock.add(const Duration(hours: 3, minutes: 59));

      expect(await repo.showAppOpen(), isTrue);

      verify(() => ad.show()).called(1);
    });

    test('Given preload(AdFormat.banner, ...), When called, '
        'Then no gateway call and no throw', () async {
      await repo.preload(AdFormat.banner, adUnitId: unit);

      verifyNever(() => gateway.loadFullScreen(any(), any()));
    });
  });

  group('loadBanner', () {
    test('Given gateway.loadBanner throws, When loadBanner, '
        'Then null', () async {
      when(
        () => gateway.loadBanner(
          adUnitId: any(named: 'adUnitId'),
          width: any(named: 'width'),
        ),
      ).thenAnswer((_) async => throw const AdLoadException(3, 'no fill'));

      expect(await repo.loadBanner(adUnitId: 'b', width: 320), isNull);
    });

    test('Given gateway.loadBanner returns a handle, When loadBanner, '
        'Then the same handle', () async {
      final handle = _FakeBannerHandle();
      when(
        () => gateway.loadBanner(
          adUnitId: any(named: 'adUnitId'),
          width: any(named: 'width'),
        ),
      ).thenAnswer((_) async => handle);

      expect(await repo.loadBanner(adUnitId: 'b', width: 320), same(handle));
    });
  });

  group('adsRepositoryProvider', () {
    test('Given the provider, When read, Then it is a '
        'GoogleMobileAdsRepository', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(adsRepositoryProvider),
        isA<GoogleMobileAdsRepository>(),
      );
    });
  });
}

class _FakeBannerHandle extends Mock implements AdBannerHandle {}
