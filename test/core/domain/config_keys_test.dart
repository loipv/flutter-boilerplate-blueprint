import 'package:blueprint_app/core/domain/config_key.dart';
import 'package:blueprint_app/core/domain/config_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Given ConfigKeys.all, When keys are compared, Then they are unique',
    () {
      final names = ConfigKeys.all.map((k) => k.key).toList();
      expect(names.toSet().length, names.length);
    },
  );

  test('Given ConfigKeys.all, When read, Then it contains apiBaseUrl', () {
    expect(ConfigKeys.all, contains(ConfigKeys.apiBaseUrl));
    expect(ConfigKeys.apiBaseUrl.key, 'api_base_url');
  });

  // BEGIN_ADS
  test('Given ConfigKeys.all, When read, Then it holds the six ads keys '
      'with their spec names and defaults', () {
    expect(
      ConfigKeys.all,
      containsAll(<Object>[
        ConfigKeys.adsEnabled,
        ConfigKeys.adsBannerEnabled,
        ConfigKeys.adsInterstitialEnabled,
        ConfigKeys.adsRewardedEnabled,
        ConfigKeys.adsAppOpenEnabled,
        ConfigKeys.adsFullScreenMinIntervalSeconds,
      ]),
    );
    expect(ConfigKeys.adsEnabled, const ConfigKey<bool>('ads_enabled', true));
    expect(
      ConfigKeys.adsBannerEnabled,
      const ConfigKey<bool>('ads_banner_enabled', true),
    );
    expect(
      ConfigKeys.adsInterstitialEnabled,
      const ConfigKey<bool>('ads_interstitial_enabled', true),
    );
    expect(
      ConfigKeys.adsRewardedEnabled,
      const ConfigKey<bool>('ads_rewarded_enabled', true),
    );
    expect(
      ConfigKeys.adsAppOpenEnabled,
      const ConfigKey<bool>('ads_app_open_enabled', true),
    );
    expect(
      ConfigKeys.adsFullScreenMinIntervalSeconds,
      const ConfigKey<int>('ads_full_screen_min_interval_seconds', 90),
    );
  });
  // END_ADS
}
