import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:blueprint_app/core/utils/app_logger.dart';
import 'package:blueprint_app/features/ads/application/ad_free_provider.dart';
import 'package:blueprint_app/features/ads/application/ads_master_switch_provider.dart';
import 'package:blueprint_app/features/ads/application/ads_settings.dart';
import 'package:blueprint_app/features/ads/data/google_mobile_ads_repository.dart';
import 'package:blueprint_app/features/ads/domain/ads_repository.dart';

part 'ads_consent_controller.g.dart';

/// Runs the consent flow and holds the resulting [AdsConsent].
///
/// Does not touch the repository (so no consent form or ATT prompt) when the
/// build flag or the Remote Config master switch is off, or the user is
/// ad-free. A failed consent flow resolves to [noAdsConsent] instead of an
/// error, so Riverpod never retries it and re-shows the form.
@Riverpod(keepAlive: true)
class AdsConsentController extends _$AdsConsentController {
  static const _log = AppLogger('AdsConsentController');

  @override
  Future<AdsConsent> build() async {
    final settings = ref.watch(adsSettingsProvider);
    if (!settings.enabled || ref.watch(adFreeProvider)) return noAdsConsent;
    if (!ref.watch(adsMasterSwitchProvider)) return noAdsConsent;
    final repository = ref.watch(adsRepositoryProvider);
    try {
      return await repository.initialize(
        debugGeographyEea: settings.debugGeographyEea,
      );
    } on Object catch (e, st) {
      _log.error('consent flow failed', error: e, stackTrace: st);
      return noAdsConsent;
    }
  }

  /// Re-opens the privacy options form and stores the new consent.
  Future<void> showPrivacyOptions() async {
    final repository = ref.read(adsRepositoryProvider);
    state = await AsyncValue.guard(repository.showPrivacyOptions);
  }
}
