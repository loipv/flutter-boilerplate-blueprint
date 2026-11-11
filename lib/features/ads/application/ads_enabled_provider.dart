import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:blueprint_app/core/domain/config_key.dart';
import 'package:blueprint_app/core/domain/config_keys.dart';
import 'package:blueprint_app/core/providers/remote_config_revision_provider.dart';
import 'package:blueprint_app/features/ads/application/ad_free_provider.dart';
import 'package:blueprint_app/features/ads/application/ads_consent_controller.dart';
import 'package:blueprint_app/features/ads/application/ads_master_switch_provider.dart';
import 'package:blueprint_app/features/ads/application/ads_settings.dart';
import 'package:blueprint_app/features/ads/domain/ad_format.dart';

part 'ads_enabled_provider.g.dart';

ConfigKey<bool> _formatKey(AdFormat format) => switch (format) {
  AdFormat.banner => ConfigKeys.adsBannerEnabled,
  AdFormat.interstitial => ConfigKeys.adsInterstitialEnabled,
  AdFormat.rewarded => ConfigKeys.adsRewardedEnabled,
  AdFormat.appOpen => ConfigKeys.adsAppOpenEnabled,
};

/// Whether ads of [format] may be shown.
///
/// Checks run in order and stop at the first that fails. The consent flow
/// itself is gated separately in [AdsConsentController] on the build flag, the
/// master switch and ad-free, so the consent form and ATT prompt never run
/// while any of those say no.
@riverpod
bool adsEnabled(Ref ref, AdFormat format) {
  final settings = ref.watch(adsSettingsProvider);
  if (!settings.enabled) return false;
  if (!ref.watch(adsMasterSwitchProvider)) return false;
  if (!ref.watchConfig(_formatKey(format))) return false;
  if (ref.watch(adFreeProvider)) return false;
  final consent = ref.watch(adsConsentControllerProvider);
  if (consent.value?.canRequestAds != true) return false;
  return settings.unitId(format) != null;
}
