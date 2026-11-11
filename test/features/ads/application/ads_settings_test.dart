import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/features/ads/application/ads_settings.dart';
import 'package:blueprint_app/features/ads/domain/ad_format.dart';
import 'package:blueprint_app/features/ads/domain/ad_unit_ids.dart';

AdsSettings _settings({
  bool useLiveIds = false,
  bool eea = false,
  AdUnitIds unitIds = const AdUnitIds({}),
}) => AdsSettings(
  enabled: true,
  useLiveIds: useLiveIds,
  platform: AdPlatform.android,
  requestEeaDebugGeography: eea,
  unitIds: unitIds,
);

void main() {
  group('debugGeographyEea', () {
    test('Given requested and test IDs, When read, Then true', () {
      expect(_settings(eea: true).debugGeographyEea, isTrue);
    });

    test('Given requested and live IDs, When read, Then false', () {
      expect(_settings(eea: true, useLiveIds: true).debugGeographyEea, isFalse);
    });

    test('Given not requested, When read, Then false', () {
      expect(_settings().debugGeographyEea, isFalse);
    });
  });

  group('unitId', () {
    test('Given useLiveIds false, When asked, Then returns the test ID', () {
      expect(
        _settings().unitId(AdFormat.banner),
        AdUnitIds.test[AdFormat.banner]![AdPlatform.android],
      );
    });

    test('Given useLiveIds true and no live ID, When asked, Then null', () {
      expect(_settings(useLiveIds: true).unitId(AdFormat.banner), isNull);
    });

    test('Given useLiveIds true and a live ID, When asked, Then it', () {
      final settings = _settings(
        useLiveIds: true,
        unitIds: const AdUnitIds({
          AdFormat.banner: {AdPlatform.android: 'live-id'},
        }),
      );

      expect(settings.unitId(AdFormat.banner), 'live-id');
    });
  });

  test('Given disabled, When read, Then enabled is false', () {
    expect(AdsSettings.disabled.enabled, isFalse);
  });
}
