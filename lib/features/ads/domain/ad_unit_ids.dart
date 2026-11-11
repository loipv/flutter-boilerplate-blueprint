import 'package:blueprint_app/features/ads/domain/ad_format.dart';

/// The platforms that have their own ad unit IDs.
enum AdPlatform { android, ios }

/// Ad unit IDs per format and platform.
///
/// Live IDs come from the build environment. Unless [resolve] is asked for
/// live IDs, it returns Google's sample IDs, so debug builds never serve or
/// click real ads.
class AdUnitIds {
  const AdUnitIds(this.live);

  /// Live IDs read from `--dart-define-from-file` values.
  static const fromEnvironment = AdUnitIds({
    AdFormat.banner: {
      AdPlatform.android: String.fromEnvironment('ADMOB_BANNER_ANDROID'),
      AdPlatform.ios: String.fromEnvironment('ADMOB_BANNER_IOS'),
    },
    AdFormat.interstitial: {
      AdPlatform.android: String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID'),
      AdPlatform.ios: String.fromEnvironment('ADMOB_INTERSTITIAL_IOS'),
    },
    AdFormat.rewarded: {
      AdPlatform.android: String.fromEnvironment('ADMOB_REWARDED_ANDROID'),
      AdPlatform.ios: String.fromEnvironment('ADMOB_REWARDED_IOS'),
    },
    AdFormat.appOpen: {
      AdPlatform.android: String.fromEnvironment('ADMOB_APP_OPEN_ANDROID'),
      AdPlatform.ios: String.fromEnvironment('ADMOB_APP_OPEN_IOS'),
    },
  });

  /// Google's sample ad unit IDs.
  static const Map<AdFormat, Map<AdPlatform, String>> test = {
    AdFormat.banner: {
      AdPlatform.android: 'ca-app-pub-3940256099942544/9214589741',
      AdPlatform.ios: 'ca-app-pub-3940256099942544/2435281174',
    },
    AdFormat.interstitial: {
      AdPlatform.android: 'ca-app-pub-3940256099942544/1033173712',
      AdPlatform.ios: 'ca-app-pub-3940256099942544/4411468910',
    },
    AdFormat.rewarded: {
      AdPlatform.android: 'ca-app-pub-3940256099942544/5224354917',
      AdPlatform.ios: 'ca-app-pub-3940256099942544/1712485313',
    },
    AdFormat.appOpen: {
      AdPlatform.android: 'ca-app-pub-3940256099942544/9257395921',
      AdPlatform.ios: 'ca-app-pub-3940256099942544/5575463023',
    },
  };

  final Map<AdFormat, Map<AdPlatform, String>> live;

  /// The ID to use, or null when [useLiveIds] is true and no live ID is set.
  String? resolve(
    AdFormat format,
    AdPlatform platform, {
    required bool useLiveIds,
  }) {
    final id = (useLiveIds ? live : test)[format]?[platform];
    return id == null || id.isEmpty ? null : id;
  }
}
