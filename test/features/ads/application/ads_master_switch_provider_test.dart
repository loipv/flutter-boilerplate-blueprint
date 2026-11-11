import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/core/data/firebase_remote_config_repository.dart';
import 'package:blueprint_app/core/domain/config_keys.dart';
import 'package:blueprint_app/features/ads/application/ads_master_switch_provider.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeRemoteConfigRepository config;

  setUp(() {
    config = FakeRemoteConfigRepository();
    addTearDown(config.dispose);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [remoteConfigRepositoryProvider.overrideWithValue(config)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('Given no Remote Config value, When read, Then the default is '
      'true', () {
    expect(makeContainer().read(adsMasterSwitchProvider), isTrue);
  });

  test('Given ads_enabled false, When read, Then false', () {
    config.values = {ConfigKeys.adsEnabled.key: false};

    expect(makeContainer().read(adsMasterSwitchProvider), isFalse);
  });

  for (final (from, to) in [(true, false), (false, true)]) {
    test('Given ads_enabled $from at first read, When Remote Config updates to '
        '$to mid-session, Then the value stays $from', () async {
      config.values = {ConfigKeys.adsEnabled.key: from};
      final container = makeContainer();
      container.listen(adsMasterSwitchProvider, (_, _) {});
      expect(container.read(adsMasterSwitchProvider), from);

      config.update({ConfigKeys.adsEnabled.key: to});
      await pumpEventQueue();

      expect(container.read(adsMasterSwitchProvider), from);
    });
  }
}
