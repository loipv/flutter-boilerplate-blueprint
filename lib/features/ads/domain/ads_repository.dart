import 'package:blueprint_app/features/ads/domain/ad_banner_handle.dart';
import 'package:blueprint_app/features/ads/domain/ad_format.dart';
import 'package:blueprint_app/features/ads/domain/rewarded_outcome.dart';

/// Consent state after the user messaging flow.
typedef AdsConsent = ({bool canRequestAds, bool privacyOptionsRequired});

/// Consent state when ads cannot be requested.
const AdsConsent noAdsConsent = (
  canRequestAds: false,
  privacyOptionsRequired: false,
);

/// Ad SDK access. No method throws; failures return [noAdsConsent], null,
/// false or [RewardUnavailable].
abstract class AdsRepository {
  Future<AdsConsent> initialize({required bool debugGeographyEea});

  Future<AdsConsent> showPrivacyOptions();

  Future<AdBannerHandle?> loadBanner({
    required String adUnitId,
    required double width,
  });

  Future<void> preload(AdFormat format, {required String adUnitId});

  Future<bool> showInterstitial();

  Future<RewardedOutcome> showRewarded();

  Future<bool> showAppOpen();
}
