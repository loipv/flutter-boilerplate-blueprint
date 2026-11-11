// coverage:ignore-file
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:blueprint_app/features/ads/domain/ad_banner_handle.dart';
import 'package:blueprint_app/features/ads/domain/ad_format.dart';
import 'package:blueprint_app/features/ads/domain/rewarded_outcome.dart';

/// Thin, logic-free wrapper over the Google Mobile Ads and UMP SDKs.
///
/// It only adapts SDK callbacks to Futures and exceptions. Decisions (retries,
/// caching, logging) live in `GoogleMobileAdsRepository`. Constructing it does
/// not touch the SDK; only calling a method does.
class GoogleMobileAdsGateway {
  const GoogleMobileAdsGateway();

  Future<void> requestConsentInfoUpdate({required bool debugGeographyEea}) {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(
        consentDebugSettings: debugGeographyEea
            ? ConsentDebugSettings(
                debugGeography: DebugGeography.debugGeographyEea,
              )
            : null,
      ),
      completer.complete,
      (error) => completer.completeError(
        StateError(
          'Consent update failed: ${error.errorCode} ${error.message}',
        ),
      ),
    );
    return completer.future;
  }

  Future<void> loadAndShowConsentFormIfRequired() {
    final completer = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error == null) {
        completer.complete();
      } else {
        completer.completeError(
          StateError(
            'Consent form failed: ${error.errorCode} ${error.message}',
          ),
        );
      }
    });
    return completer.future;
  }

  Future<void> showPrivacyOptionsForm() {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (error == null) {
        completer.complete();
      } else {
        completer.completeError(
          StateError(
            'Privacy options form failed: ${error.errorCode} ${error.message}',
          ),
        );
      }
    });
    return completer.future;
  }

  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  Future<void> initializeSdk() => MobileAds.instance.initialize();

  /// Throws [AdLoadException].
  Future<AdBannerHandle> loadBanner({
    required String adUnitId,
    required double width,
  }) async {
    // ignore: deprecated_member_use
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width.truncate(),
    );
    if (size == null) {
      throw const AdLoadException(-1, 'Adaptive banner size unavailable');
    }
    final completer = Completer<AdBannerHandle>();
    final banner = BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) {
            completer.complete(_BannerHandle(ad as BannerAd, size));
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!completer.isCompleted) {
            completer.completeError(AdLoadException(error.code, error.message));
          }
        },
      ),
    );
    await banner.load();
    return completer.future;
  }

  /// Throws [AdLoadException]. [format] is interstitial, rewarded or appOpen.
  Future<LoadedAd> loadFullScreen(AdFormat format, String adUnitId) {
    final completer = Completer<LoadedAd>();
    void onFailed(LoadAdError error) {
      if (!completer.isCompleted) {
        completer.completeError(AdLoadException(error.code, error.message));
      }
    }

    switch (format) {
      case AdFormat.interstitial:
        InterstitialAd.load(
          adUnitId: adUnitId,
          request: const AdRequest(),
          adLoadCallback: InterstitialAdLoadCallback(
            onAdLoaded: (ad) => completer.complete(
              _FullScreenAd(
                dispose: ad.dispose,
                show: (state) {
                  ad.fullScreenContentCallback = state
                      .callback<InterstitialAd>();
                  return ad.show();
                },
              ),
            ),
            onAdFailedToLoad: onFailed,
          ),
        );
      case AdFormat.rewarded:
        RewardedAd.load(
          adUnitId: adUnitId,
          request: const AdRequest(),
          rewardedAdLoadCallback: RewardedAdLoadCallback(
            onAdLoaded: (ad) => completer.complete(
              _FullScreenAd(
                dispose: ad.dispose,
                show: (state) {
                  ad.fullScreenContentCallback = state.callback<RewardedAd>();
                  return ad.show(
                    onUserEarnedReward: (_, item) => state.earned =
                        RewardEarned(item.amount.toInt(), item.type),
                  );
                },
              ),
            ),
            onAdFailedToLoad: onFailed,
          ),
        );
      case AdFormat.appOpen:
        AppOpenAd.load(
          adUnitId: adUnitId,
          request: const AdRequest(),
          adLoadCallback: AppOpenAdLoadCallback(
            onAdLoaded: (ad) => completer.complete(
              _FullScreenAd(
                dispose: ad.dispose,
                show: (state) {
                  ad.fullScreenContentCallback = state.callback<AppOpenAd>();
                  return ad.show();
                },
              ),
            ),
            onAdFailedToLoad: onFailed,
          ),
        );
      case AdFormat.banner:
        throw ArgumentError.value(format, 'format', 'Use loadBanner');
    }
    return completer.future;
  }
}

/// A loaded full-screen ad, ready to show once.
abstract class LoadedAd {
  /// Completes when the ad is dismissed or fails to show.
  Future<AdShowResult> show();

  void dispose();
}

class AdShowResult {
  const AdShowResult({required this.shown, this.reward});

  final bool shown;
  final RewardEarned? reward;
}

class AdLoadException implements Exception {
  const AdLoadException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'AdLoadException($code, $message)';
}

class _BannerHandle implements AdBannerHandle {
  _BannerHandle(this._ad, AdSize size)
    : size = Size(size.width.toDouble(), size.height.toDouble());

  final BannerAd _ad;

  @override
  final Size size;

  @override
  Widget get widget => AdWidget(ad: _ad);

  @override
  void dispose() => _ad.dispose();
}

/// Shared show state: completes the show Future on dismiss or show failure.
class _ShowState {
  final Completer<AdShowResult> done = Completer<AdShowResult>();
  RewardEarned? earned;

  FullScreenContentCallback<T> callback<T extends Ad>() =>
      FullScreenContentCallback<T>(
        onAdDismissedFullScreenContent: (_) {
          if (!done.isCompleted) {
            done.complete(AdShowResult(shown: true, reward: earned));
          }
        },
        onAdFailedToShowFullScreenContent: (_, _) {
          if (!done.isCompleted) {
            done.complete(const AdShowResult(shown: false));
          }
        },
      );
}

class _FullScreenAd implements LoadedAd {
  _FullScreenAd({
    required void Function() dispose,
    required Future<void> Function(_ShowState) show,
  }) : _dispose = dispose,
       _show = show;

  final void Function() _dispose;
  final Future<void> Function(_ShowState) _show;
  final _ShowState _state = _ShowState();

  @override
  Future<AdShowResult> show() async {
    await _show(_state);
    return _state.done.future;
  }

  @override
  void dispose() => _dispose();
}
