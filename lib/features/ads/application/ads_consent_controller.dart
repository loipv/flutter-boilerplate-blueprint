import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:blueprint_app/core/domain/config_keys.dart';
import 'package:blueprint_app/core/providers/remote_config_revision_provider.dart';
import 'package:blueprint_app/features/ads/application/ad_free_provider.dart';
import 'package:blueprint_app/features/ads/application/ads_settings.dart';
import 'package:blueprint_app/features/ads/data/google_mobile_ads_repository.dart';
import 'package:blueprint_app/features/ads/domain/ads_repository.dart';

part 'ads_consent_controller.g.dart';

/// Runs the consent flow and holds the resulting [AdsConsent].
///
/// Does not touch the repository (so no consent form or ATT prompt) when the
/// build flag or the Remote Config master switch is off, or the user is
/// ad-free.
@Riverpod(keepAlive: true)
class AdsConsentController extends _$AdsConsentController {
  @override
  Future<AdsConsent> build() async {
    final settings = ref.watch(adsSettingsProvider);
    if (!settings.enabled || ref.watch(adFreeProvider)) return noAdsConsent;
    if (!ref.watchConfig(ConfigKeys.adsEnabled)) return noAdsConsent;
    return ref
        .watch(adsRepositoryProvider)
        .initialize(debugGeographyEea: settings.debugGeographyEea);
  }

  /// Re-opens the privacy options form and stores the new consent.
  Future<void> showPrivacyOptions() async {
    final repository = ref.read(adsRepositoryProvider);
    state = await AsyncValue.guard(repository.showPrivacyOptions);
  }
}
