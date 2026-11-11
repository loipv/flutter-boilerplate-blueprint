import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:blueprint_app/features/ads/domain/ad_format.dart';
import 'package:blueprint_app/features/ads/domain/ad_unit_ids.dart';

part 'ads_settings.g.dart';

/// Build-time ad configuration, read once at startup.
class AdsSettings {
  const AdsSettings({
    required this.enabled,
    required this.useLiveIds,
    required this.platform,
    required this.requestEeaDebugGeography,
    required this.unitIds,
  });

  /// Ads are off: the build flag is false.
  static const disabled = AdsSettings(
    enabled: false,
    useLiveIds: false,
    platform: AdPlatform.android,
    requestEeaDebugGeography: false,
    unitIds: AdUnitIds({}),
  );

  /// Build flag: ads are compiled in and switched on.
  final bool enabled;

  /// True in production, where live IDs replace Google's sample IDs.
  final bool useLiveIds;
  final AdPlatform platform;
  final bool requestEeaDebugGeography;
  final AdUnitIds unitIds;

  /// Simulates an EEA user, but never with live IDs.
  bool get debugGeographyEea => requestEeaDebugGeography && !useLiveIds;

  /// The unit ID for [format], or null when none is configured.
  String? unitId(AdFormat format) =>
      unitIds.resolve(format, platform, useLiveIds: useLiveIds);
}

/// Defaults to [AdsSettings.disabled]. `main.dart` overrides it.
@Riverpod(keepAlive: true)
AdsSettings adsSettings(Ref ref) => AdsSettings.disabled;
