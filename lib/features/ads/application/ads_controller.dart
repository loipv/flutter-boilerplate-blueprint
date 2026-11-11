import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:blueprint_app/core/data/firebase_remote_config_repository.dart';
import 'package:blueprint_app/core/domain/config_keys.dart';
import 'package:blueprint_app/core/utils/app_logger.dart';
import 'package:blueprint_app/features/ads/application/ad_frequency_cap.dart';
import 'package:blueprint_app/features/ads/application/ads_consent_controller.dart';
import 'package:blueprint_app/features/ads/application/ads_enabled_provider.dart';
import 'package:blueprint_app/features/ads/application/ads_settings.dart';
import 'package:blueprint_app/features/ads/data/google_mobile_ads_repository.dart';
import 'package:blueprint_app/features/ads/domain/ad_banner_handle.dart';
import 'package:blueprint_app/features/ads/domain/ad_format.dart';
import 'package:blueprint_app/features/ads/domain/ads_repository.dart';
import 'package:blueprint_app/features/ads/domain/rewarded_outcome.dart';

part 'ads_controller.g.dart';

/// The single entry point app code uses to load banners and to preload and
/// show full-screen ads.
///
/// Never throws: repository failures are logged and reported as "no ad".
class AdsController {
  AdsController({
    required AdsRepository repository,
    required bool Function(AdFormat) isEnabled,
    required String? Function(AdFormat) unitId,
    required AdFrequencyCap cap,
  }) : _repository = repository,
       _isEnabled = isEnabled,
       _unitId = unitId,
       _cap = cap;

  static const _log = AppLogger('AdsController');
  static const _appOpenQuietPeriod = Duration(seconds: 5);

  final AdsRepository _repository;
  final bool Function(AdFormat) _isEnabled;
  final String? Function(AdFormat) _unitId;
  final AdFrequencyCap _cap;
  bool _showingFullScreen = false;

  /// Preloads every full-screen format that is enabled.
  void preloadEnabled() {
    for (final format in const [
      AdFormat.interstitial,
      AdFormat.rewarded,
      AdFormat.appOpen,
    ]) {
      _preload(format);
    }
  }

  /// Loads an adaptive banner [width] wide. Returns null when banners are off,
  /// no unit ID is set, there is no fill, or the load fails.
  Future<AdBannerHandle?> loadBanner({required double width}) async {
    if (!_isEnabled(AdFormat.banner)) return null;
    final id = _unitId(AdFormat.banner);
    if (id == null) return null;
    try {
      return await _repository.loadBanner(adUnitId: id, width: width);
    } on Object catch (e, st) {
      _log.warning('load banner failed', error: e, stackTrace: st);
      return null;
    }
  }

  Future<bool> maybeShowInterstitial() async {
    if (!_canShow(AdFormat.interstitial) || !_cap.canShowFullScreen()) {
      return false;
    }
    return _guard(
      AdFormat.interstitial,
      _repository.showInterstitial,
      shown: (shown) => shown,
      unavailable: false,
    );
  }

  Future<RewardedOutcome> showRewarded() async {
    if (!_canShow(AdFormat.rewarded)) return const RewardUnavailable();
    return _guard(
      AdFormat.rewarded,
      _repository.showRewarded,
      shown: (outcome) => outcome is! RewardUnavailable,
      unavailable: const RewardUnavailable(),
    );
  }

  Future<bool> maybeShowAppOpen() async {
    if (!_canShow(AdFormat.appOpen) ||
        !_cap.canShowFullScreen() ||
        _cap.closedWithin(_appOpenQuietPeriod)) {
      return false;
    }
    return _guard(
      AdFormat.appOpen,
      _repository.showAppOpen,
      shown: (shown) => shown,
      unavailable: false,
    );
  }

  bool _canShow(AdFormat format) => !_showingFullScreen && _isEnabled(format);

  void _preload(AdFormat format) {
    if (!_isEnabled(format)) return;
    final id = _unitId(format);
    if (id == null) return;
    _safePreload(format, id);
  }

  Future<void> _safePreload(AdFormat format, String id) async {
    try {
      await _repository.preload(format, adUnitId: id);
    } on Object catch (e, st) {
      _log.warning('preload $format failed', error: e, stackTrace: st);
    }
  }

  Future<T> _guard<T>(
    AdFormat format,
    Future<T> Function() show, {
    required bool Function(T) shown,
    required T unavailable,
  }) async {
    _showingFullScreen = true;
    try {
      final result = await show();
      if (shown(result)) {
        _cap.recordFullScreenClosed();
      } else {
        _preload(format);
      }
      return result;
    } on Object catch (e, st) {
      _log.error('show $format failed', error: e, stackTrace: st);
      _preload(format);
      return unavailable;
    } finally {
      _showingFullScreen = false;
    }
  }
}

@Riverpod(keepAlive: true)
AdsController adsController(Ref ref) {
  final settings = ref.read(adsSettingsProvider);
  final controller = AdsController(
    repository: ref.read(adsRepositoryProvider),
    isEnabled: (format) => ref.read(adsEnabledProvider(format)),
    unitId: settings.unitId,
    cap: AdFrequencyCap(
      // Read lazily: Remote Config is only touched once an ad may be shown.
      minInterval: () => Duration(
        seconds: ref
            .read(remoteConfigRepositoryProvider)
            .get(ConfigKeys.adsFullScreenMinIntervalSeconds),
      ),
    ),
  );
  ref.listen(adsConsentControllerProvider, (_, next) {
    if (next.value?.canRequestAds == true) controller.preloadEnabled();
  }, fireImmediately: true);
  return controller;
}
