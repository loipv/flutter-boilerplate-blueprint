import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blueprint_app/core/theme/app_theme.dart';
import 'package:blueprint_app/features/ads/application/ads_enabled_provider.dart';
import 'package:blueprint_app/features/ads/application/ads_settings.dart';
import 'package:blueprint_app/features/ads/data/google_mobile_ads_repository.dart';
import 'package:blueprint_app/features/ads/domain/ad_banner_handle.dart';
import 'package:blueprint_app/features/ads/domain/ad_format.dart';
import 'package:blueprint_app/features/ads/domain/ad_unit_ids.dart';
import 'package:blueprint_app/features/ads/presentation/ad_banner.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/mocks.dart';

const _bannerId = 'ca-app-pub-3940256099942544/9214589741';

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

  Widget app({required bool enabled, Widget? child}) {
    return ProviderScope(
      overrides: [
        adsRepositoryProvider.overrideWithValue(repository),
        adsSettingsProvider.overrideWithValue(_settings),
        adsEnabledProvider(AdFormat.banner).overrideWithValue(enabled),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child ?? const AdBanner()),
      ),
    );
  }

  void stubLoad(AdBannerHandle? handle) {
    when(
      () => repository.loadBanner(
        adUnitId: any(named: 'adUnitId'),
        width: any(named: 'width'),
      ),
    ).thenAnswer((_) async => handle);
  }

  testWidgets('Given ads disabled, When built, Then nothing shows and '
      'loadBanner is never called', (tester) async {
    await tester.pumpWidget(app(enabled: false));
    await tester.pumpAndSettle();

    expect(find.text('fake-banner'), findsNothing);
    verifyNever(
      () => repository.loadBanner(
        adUnitId: any(named: 'adUnitId'),
        width: any(named: 'width'),
      ),
    );
  });

  testWidgets('Given ads enabled, When built, Then loadBanner gets the test '
      'unit id and the banner shows', (tester) async {
    stubLoad(FakeAdBannerHandle());

    await tester.pumpWidget(app(enabled: true));
    await tester.pumpAndSettle();

    verify(
      () => repository.loadBanner(
        adUnitId: _bannerId,
        width: any(named: 'width'),
      ),
    ).called(1);
    expect(find.text('fake-banner'), findsOneWidget);
  });

  testWidgets('Given loadBanner returns null, When built, Then nothing shows '
      'and the size is zero', (tester) async {
    stubLoad(null);

    await tester.pumpWidget(app(enabled: true));
    await tester.pumpAndSettle();

    expect(find.text('fake-banner'), findsNothing);
    expect(tester.getSize(find.byType(AdBanner)), Size.zero);
  });

  testWidgets('Given a loaded banner, When unmounted, Then the handle is '
      'disposed', (tester) async {
    final handle = FakeAdBannerHandle();
    stubLoad(handle);
    await tester.pumpWidget(app(enabled: true));
    await tester.pumpAndSettle();

    await tester.pumpWidget(app(enabled: true, child: const Text('other')));
    await tester.pumpAndSettle();

    expect(handle.disposed, isTrue);
  });

  testWidgets('Given a loaded banner, When ads turn off, Then the handle is '
      'disposed and the banner is gone', (tester) async {
    final handle = FakeAdBannerHandle();
    stubLoad(handle);
    await tester.pumpWidget(app(enabled: true));
    await tester.pumpAndSettle();
    expect(find.text('fake-banner'), findsOneWidget);

    await tester.pumpWidget(app(enabled: false));
    await tester.pumpAndSettle();

    expect(handle.disposed, isTrue);
    expect(find.text('fake-banner'), findsNothing);
  });

  testWidgets('Given a load in flight, When unmounted before it completes, '
      'Then the late handle is disposed without error', (tester) async {
    final handle = FakeAdBannerHandle();
    final completer = Completer<AdBannerHandle?>();
    when(
      () => repository.loadBanner(
        adUnitId: any(named: 'adUnitId'),
        width: any(named: 'width'),
      ),
    ).thenAnswer((_) => completer.future);
    await tester.pumpWidget(app(enabled: true));
    await tester.pump();

    await tester.pumpWidget(app(enabled: true, child: const Text('other')));
    completer.complete(handle);
    await tester.pumpAndSettle();

    expect(handle.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
