import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:blueprint_app/core/utils/app_logger.dart';
import 'package:blueprint_app/features/ads/data/google_mobile_ads_gateway.dart';
import 'package:blueprint_app/features/ads/domain/ad_banner_handle.dart';
import 'package:blueprint_app/features/ads/domain/ad_format.dart';
import 'package:blueprint_app/features/ads/domain/ads_repository.dart';
import 'package:blueprint_app/features/ads/domain/rewarded_outcome.dart';

part 'google_mobile_ads_repository.g.dart';

/// Google Mobile Ads implementation of [AdsRepository].
///
/// Holds the consent and ad logic; all SDK access goes through
/// [GoogleMobileAdsGateway]. Constructing it never touches the SDK.
class GoogleMobileAdsRepository implements AdsRepository {
  GoogleMobileAdsRepository(
    this._gateway, {
    DateTime Function() now = DateTime.now,
  }) : _now = now;

  final GoogleMobileAdsGateway _gateway;
  // ignore: unused_field
  final DateTime Function() _now;

  static const _log = AppLogger('GoogleMobileAdsRepository');

  Future<void>? _sdkInit;

  @override
  Future<AdsConsent> initialize({required bool debugGeographyEea}) async {
    await _guard(
      'requestConsentInfoUpdate',
      () => _gateway.requestConsentInfoUpdate(
        debugGeographyEea: debugGeographyEea,
      ),
    );
    if (await _readCanRequestAds()) _startSdk();
    await _guard('loadAndShowConsentFormIfRequired', () async {
      await _gateway.loadAndShowConsentFormIfRequired();
    });
    final canRequestAds = await _readCanRequestAds();
    if (canRequestAds) _startSdk();
    final privacyOptionsRequired = await _readPrivacyOptionsRequired();
    if (_sdkInit case final init?) await init;
    return (
      canRequestAds: canRequestAds,
      privacyOptionsRequired: privacyOptionsRequired,
    );
  }

  @override
  Future<AdsConsent> showPrivacyOptions() async {
    await _guard('showPrivacyOptionsForm', _gateway.showPrivacyOptionsForm);
    return (
      canRequestAds: await _readCanRequestAds(),
      privacyOptionsRequired: await _readPrivacyOptionsRequired(),
    );
  }

  @override
  Future<AdBannerHandle?> loadBanner({
    required String adUnitId,
    required double width,
  }) => throw UnimplementedError();

  @override
  Future<void> preload(AdFormat format, {required String adUnitId}) =>
      throw UnimplementedError();

  @override
  Future<bool> showInterstitial() => throw UnimplementedError();

  @override
  Future<RewardedOutcome> showRewarded() => throw UnimplementedError();

  @override
  Future<bool> showAppOpen() => throw UnimplementedError();

  /// Starts the SDK once; never throws and is never awaited behind the form.
  void _startSdk() {
    _sdkInit ??= _guard('initializeSdk', _gateway.initializeSdk);
  }

  Future<bool> _readCanRequestAds() async =>
      await _guard('canRequestAds', _gateway.canRequestAds) ?? false;

  Future<bool> _readPrivacyOptionsRequired() async =>
      await _guard('privacyOptionsRequired', _gateway.privacyOptionsRequired) ??
      false;

  /// Runs [call], catching sync and async errors. Returns null on failure.
  Future<T?> _guard<T>(String step, FutureOr<T> Function() call) async {
    try {
      return await call();
    } catch (e, st) {
      _log.error('$step failed', error: e, stackTrace: st);
      return null;
    }
  }
}

/// Exposes the ABSTRACT type so consumers never depend on the SDK directly.
@Riverpod(keepAlive: true)
AdsRepository adsRepository(Ref ref) =>
    GoogleMobileAdsRepository(const GoogleMobileAdsGateway());
