import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blueprint_app/core/l10n/locale_provider.dart';
import 'package:blueprint_app/core/services/notification_service.dart';
import 'package:blueprint_app/features/auth/domain/user_entity.dart';
import 'package:blueprint_app/features/auth/domain/user_preferences.dart';
import 'package:blueprint_app/features/notifications/application/notification_scheduler.dart';
import 'package:blueprint_app/features/user_profile/application/user_profile_providers.dart';

import '../../../helpers/pump_app.dart';

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  setUpAll(() => registerFallbackValue(const TimeOfDay(hour: 0, minute: 0)));

  late MockNotificationService service;
  late StreamController<String?> taps;
  late StreamController<UserEntity?> profile;
  late ProviderContainer container;

  UserEntity userWith(String? time) => UserEntity(
    id: 'u1',
    preferences: UserPreferences(notificationTime: time),
  );

  Future<void> pumpScheduler(WidgetTester tester) => pumpApp(
    tester,
    Consumer(
      builder: (context, ref, _) {
        container = ProviderScope.containerOf(context);
        return const NotificationScheduler(child: Text('child'));
      },
    ),
    overrides: [
      notificationServiceProvider.overrideWithValue(service),
      userProfileStreamProvider.overrideWith((ref) => profile.stream),
    ],
  );

  Future<void> emit(WidgetTester tester, UserEntity? user) async {
    profile.add(user);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = MockNotificationService();
    taps = StreamController<String?>.broadcast();
    profile = StreamController<UserEntity?>();
    when(() => service.onNotificationTap).thenAnswer((_) => taps.stream);
    when(
      () => service.scheduleDailyNotification(
        time: any(named: 'time'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        channelName: any(named: 'channelName'),
        channelDescription: any(named: 'channelDescription'),
      ),
    ).thenAnswer((_) async {});
    when(() => service.cancelDailyNotification()).thenAnswer((_) async {});
    addTearDown(() async {
      await taps.close();
      await profile.close();
    });
  });

  group('NotificationScheduler', () {
    testWidgets('Given the scheduler, When pumped, Then it renders its child', (
      tester,
    ) async {
      await pumpScheduler(tester);

      expect(find.text('child'), findsOneWidget);
    });

    testWidgets(
      'Given no preference change, When pumped, Then nothing is scheduled or cancelled',
      (tester) async {
        await pumpScheduler(tester);
        await emit(tester, userWith(null));

        verifyNever(
          () => service.scheduleDailyNotification(
            time: any(named: 'time'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            channelName: any(named: 'channelName'),
            channelDescription: any(named: 'channelDescription'),
          ),
        );
        verifyNever(() => service.cancelDailyNotification());
      },
    );

    testWidgets(
      'Given the preference changes to 08:30, When the profile emits, Then it schedules 08:30 and stores hour and minute',
      (tester) async {
        await pumpScheduler(tester);

        await emit(tester, userWith('08:30'));

        verify(
          () => service.scheduleDailyNotification(
            time: const TimeOfDay(hour: 8, minute: 30),
            title: any(named: 'title'),
            body: any(named: 'body'),
            channelName: any(named: 'channelName'),
            channelDescription: any(named: 'channelDescription'),
          ),
        ).called(1);
        final prefs = await tester.runAsync(SharedPreferences.getInstance);
        expect(prefs!.getInt(NotificationService.kNotificationHour), 8);
        expect(prefs.getInt(NotificationService.kNotificationMinute), 30);
      },
    );

    testWidgets(
      'Given a reminder at 08:00, When the profile emits it, Then scheduleDailyNotification gets title Reminder and body Your daily reminder is ready.',
      (tester) async {
        await pumpScheduler(tester);

        await emit(tester, userWith('08:00'));

        verify(
          () => service.scheduleDailyNotification(
            time: const TimeOfDay(hour: 8, minute: 0),
            title: 'Reminder',
            body: 'Your daily reminder is ready.',
            channelName: 'Daily reminders',
            channelDescription: 'Recurring reminders for your app',
          ),
        ).called(1);
      },
    );

    testWidgets(
      'Given a reminder at 08:00 is set, When localeProvider.setLocale(vi) is called, Then scheduleDailyNotification is called again with title Nhắc nhở',
      (tester) async {
        await pumpScheduler(tester);
        await emit(tester, userWith('08:00'));

        await container
            .read(localeProvider.notifier)
            .setLocale(const Locale('vi'));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();

        verify(
          () => service.scheduleDailyNotification(
            time: const TimeOfDay(hour: 8, minute: 0),
            title: 'Nhắc nhở',
            body: 'Lời nhắc hằng ngày của bạn đã sẵn sàng.',
            channelName: 'Lời nhắc hằng ngày',
            channelDescription: 'Lời nhắc định kỳ từ ứng dụng',
          ),
        ).called(1);
      },
    );

    testWidgets(
      'Given no reminder, When localeProvider.setLocale(vi) is called, Then nothing is scheduled',
      (tester) async {
        await pumpScheduler(tester);
        await emit(tester, userWith(null));

        await container
            .read(localeProvider.notifier)
            .setLocale(const Locale('vi'));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();

        verifyNever(
          () => service.scheduleDailyNotification(
            time: any(named: 'time'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            channelName: any(named: 'channelName'),
            channelDescription: any(named: 'channelDescription'),
          ),
        );
      },
    );

    testWidgets(
      'Given a scheduled time, When the preference changes to null, Then it cancels and clears stored time',
      (tester) async {
        await pumpScheduler(tester);
        await emit(tester, userWith('08:30'));

        await emit(tester, userWith(null));

        verify(() => service.cancelDailyNotification()).called(1);
        final prefs = await tester.runAsync(SharedPreferences.getInstance);
        expect(
          prefs!.containsKey(NotificationService.kNotificationHour),
          false,
        );
        expect(
          prefs.containsKey(NotificationService.kNotificationMinute),
          false,
        );
      },
    );

    testWidgets(
      'Given a scheduled time, When the preference becomes an empty string, Then it cancels',
      (tester) async {
        await pumpScheduler(tester);
        await emit(tester, userWith('08:30'));

        await emit(tester, userWith(''));

        verify(() => service.cancelDailyNotification()).called(1);
      },
    );

    testWidgets(
      'Given a scheduled time, When the same time is emitted again, Then it does not reschedule',
      (tester) async {
        await pumpScheduler(tester);
        await emit(tester, userWith('08:30'));

        await emit(tester, userWith('08:30'));

        verify(
          () => service.scheduleDailyNotification(
            time: any(named: 'time'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            channelName: any(named: 'channelName'),
            channelDescription: any(named: 'channelDescription'),
          ),
        ).called(1);
      },
    );

    for (final invalid in ['0830', 'aa:bb', '08:30:00']) {
      testWidgets(
        'Given the preference changes to invalid "$invalid", When the profile emits, Then it ignores it',
        (tester) async {
          await pumpScheduler(tester);

          await emit(tester, userWith(invalid));

          verifyNever(
            () => service.scheduleDailyNotification(
              time: any(named: 'time'),
              title: any(named: 'title'),
              body: any(named: 'body'),
              channelName: any(named: 'channelName'),
              channelDescription: any(named: 'channelDescription'),
            ),
          );
          verifyNever(() => service.cancelDailyNotification());
          final prefs = await tester.runAsync(SharedPreferences.getInstance);
          expect(
            prefs!.containsKey(NotificationService.kNotificationHour),
            false,
          );
        },
      );
    }

    testWidgets(
      'Given the profile stream errors, When it emits an error, Then the scheduler keeps rendering and does not schedule',
      (tester) async {
        await pumpScheduler(tester);

        profile.addError(Exception('boom'));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();

        expect(find.text('child'), findsOneWidget);
        verifyNever(
          () => service.scheduleDailyNotification(
            time: any(named: 'time'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            channelName: any(named: 'channelName'),
            channelDescription: any(named: 'channelDescription'),
          ),
        );
      },
    );

    testWidgets(
      'Given the scheduler is mounted, When payloads arrive on the tap stream, Then it handles them without error',
      (tester) async {
        await pumpScheduler(tester);

        expect(taps.hasListener, isTrue);
        taps
          ..add(null)
          ..add('')
          ..add('daily_reminder');
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('child'), findsOneWidget);
      },
    );

    testWidgets(
      'Given the scheduler is mounted, When it is disposed, Then it cancels the tap subscription',
      (tester) async {
        await pumpScheduler(tester);
        expect(taps.hasListener, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());

        expect(taps.hasListener, isFalse);
      },
    );
  });
}
