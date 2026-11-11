import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blueprint_app/features/ads/data/google_mobile_ads_repository.dart';
import 'package:blueprint_app/features/ads/domain/ads_repository.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockGoogleMobileAdsGateway gateway;
  late GoogleMobileAdsRepository repo;

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
