import 'package:blueprint_app/features/ads/domain/ad_format.dart';
import 'package:blueprint_app/features/ads/domain/ad_unit_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const live = AdUnitIds({
    AdFormat.banner: {AdPlatform.android: 'live-banner-a', AdPlatform.ios: ''},
  });

  test('Given useLiveIds false, When resolved, Then Google test IDs are '
      'returned even when a live ID is set', () {
    expect(
      live.resolve(AdFormat.banner, AdPlatform.android, useLiveIds: false),
      'ca-app-pub-3940256099942544/9214589741',
    );
  });

  test('Given useLiveIds true and a live ID, When resolved, '
      'Then it is returned', () {
    expect(
      live.resolve(AdFormat.banner, AdPlatform.android, useLiveIds: true),
      'live-banner-a',
    );
  });

  test('Given useLiveIds true and an empty or missing live ID, '
      'When resolved, Then null', () {
    expect(
      live.resolve(AdFormat.banner, AdPlatform.ios, useLiveIds: true),
      isNull,
    );
    expect(
      live.resolve(AdFormat.rewarded, AdPlatform.ios, useLiveIds: true),
      isNull,
    );
  });

  test('Given every format and platform, When test IDs are read, '
      'Then each matches the spec table', () {
    const expected = {
      (AdFormat.banner, AdPlatform.android):
          'ca-app-pub-3940256099942544/9214589741',
      (AdFormat.banner, AdPlatform.ios):
          'ca-app-pub-3940256099942544/2435281174',
      (AdFormat.interstitial, AdPlatform.android):
          'ca-app-pub-3940256099942544/1033173712',
      (AdFormat.interstitial, AdPlatform.ios):
          'ca-app-pub-3940256099942544/4411468910',
      (AdFormat.rewarded, AdPlatform.android):
          'ca-app-pub-3940256099942544/5224354917',
      (AdFormat.rewarded, AdPlatform.ios):
          'ca-app-pub-3940256099942544/1712485313',
      (AdFormat.appOpen, AdPlatform.android):
          'ca-app-pub-3940256099942544/9257395921',
      (AdFormat.appOpen, AdPlatform.ios):
          'ca-app-pub-3940256099942544/5575463023',
    };
    for (final entry in expected.entries) {
      expect(
        live.resolve(entry.key.$1, entry.key.$2, useLiveIds: false),
        entry.value,
      );
    }
  });

  test('Given no live IDs set, When fromEnvironment is resolved with live '
      'IDs, Then null', () {
    expect(
      AdUnitIds.fromEnvironment.resolve(
        AdFormat.appOpen,
        AdPlatform.ios,
        useLiveIds: true,
      ),
      isNull,
    );
  });
}
