import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/core/domain/config_key.dart';
import 'package:blueprint_app/core/data/firebase_remote_config_repository.dart';
import 'package:blueprint_app/core/providers/remote_config_revision_provider.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const flag = ConfigKey<bool>('flag', false);

final probe = Provider<bool>((ref) => ref.watchConfig(flag));

class _FlagText extends ConsumerWidget {
  const _FlagText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text('${ref.watchConfig(flag)}');
  }
}

void main() {
  late FakeRemoteConfigRepository fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeRemoteConfigRepository();
    container = ProviderContainer(
      overrides: [remoteConfigRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
  });

  test('Given no updates, When read, Then the revision is 0', () {
    container.listen(remoteConfigRevisionProvider, (_, _) {});

    expect(container.read(remoteConfigRevisionProvider), 0);
  });

  test(
    'Given two onUpdated events, When read, Then the revision is 2',
    () async {
      container.listen(remoteConfigRevisionProvider, (_, _) {});

      fake.update({'flag': true});
      fake.update({'flag': false});
      await pumpEventQueue();

      expect(container.read(remoteConfigRevisionProvider), 2);
    },
  );

  test('Given a provider using ref.watchConfig, When the fake updates flag to '
      'true, Then the provider recomputes to true', () async {
    container.listen(probe, (_, _) {});
    expect(container.read(probe), isFalse);

    fake.update({'flag': true});
    await pumpEventQueue();

    expect(container.read(probe), isTrue);
  });

  test(
    'Given values changed before anything watched, When watchConfig is first '
    'read, Then it returns the new value',
    () {
      fake.update({'flag': true});

      container.listen(probe, (_, _) {});

      expect(container.read(probe), isTrue);
    },
  );

  testWidgets(
    'Given a ConsumerWidget showing ref.watchConfig, When the fake updates, '
    'Then the text changes from "false" to "true"',
    (tester) async {
      await pumpApp(
        tester,
        const _FlagText(),
        overrides: [remoteConfigRepositoryProvider.overrideWithValue(fake)],
      );
      expect(find.text('false'), findsOneWidget);

      fake.update({'flag': true});
      // First pump delivers the stream event, second rebuilds the widget.
      await tester.pump();
      await tester.pump();

      expect(find.text('true'), findsOneWidget);
    },
  );
}
