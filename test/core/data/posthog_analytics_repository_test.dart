import 'package:flutter_test/flutter_test.dart';
// BEGIN_POSTHOG
import 'package:mocktail/mocktail.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
// END_POSTHOG
import 'package:blueprint_app/core/data/posthog_analytics_repository.dart';

// BEGIN_POSTHOG
class MockPosthog extends Mock implements Posthog {}

// END_POSTHOG

void main() {
  // BEGIN_POSTHOG
  late MockPosthog posthog;
  // END_POSTHOG
  late PostHogAnalyticsRepository repository;

  setUp(() {
    // BEGIN_POSTHOG
    posthog = MockPosthog();
    when(
      () => posthog.capture(
        eventName: any(named: 'eventName'),
        properties: any(named: 'properties'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => posthog.screen(screenName: any(named: 'screenName')),
    ).thenAnswer((_) async {});
    when(() => posthog.reset()).thenAnswer((_) async {});
    // END_POSTHOG
    repository = PostHogAnalyticsRepository(
      // BEGIN_POSTHOG
      posthog,
      // END_POSTHOG
    );
  });

  group('analytics calls', () {
    test(
      'Given the repository, When capturing and resetting, Then they complete',
      () async {
        await repository.captureEvent('e', properties: {'k': 'v'});
        await repository.captureScreen('Home');
        await repository.reset();
      },
    );
  });

  // BEGIN_POSTHOG
  group('captureEvent', () {
    test(
      'Given properties, When called, Then Posthog.capture is used',
      () async {
        await repository.captureEvent('e', properties: {'k': 'v'});

        verify(
          () => posthog.capture(eventName: 'e', properties: {'k': 'v'}),
        ).called(1);
      },
    );

    test('Given the SDK throws, When called, Then it is swallowed', () async {
      when(
        () => posthog.capture(
          eventName: any(named: 'eventName'),
          properties: any(named: 'properties'),
        ),
      ).thenThrow(Exception('boom'));

      await repository.captureEvent('e');
    });
  });

  group('captureScreen', () {
    test('Given a name, When called, Then Posthog.screen is used', () async {
      await repository.captureScreen('Home');

      verify(() => posthog.screen(screenName: 'Home')).called(1);
    });

    test('Given the SDK throws, When called, Then it is swallowed', () async {
      when(
        () => posthog.screen(screenName: any(named: 'screenName')),
      ).thenThrow(Exception('boom'));

      await repository.captureScreen('Home');
    });
  });

  group('reset', () {
    test(
      'Given the repository, When called, Then Posthog.reset is used',
      () async {
        await repository.reset();

        verify(() => posthog.reset()).called(1);
      },
    );

    test('Given the SDK throws, When called, Then it is swallowed', () async {
      when(() => posthog.reset()).thenThrow(Exception('boom'));

      await repository.reset();
    });
  });
  // END_POSTHOG
}
