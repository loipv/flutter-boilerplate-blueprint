import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/features/ads/application/app_open_ad_observer.dart';

void main() {
  late int calls;
  late AppOpenAdObserver observer;

  setUp(() {
    calls = 0;
    observer = AppOpenAdObserver(
      onResumed: () async {
        calls++;
        return true;
      },
    );
  });

  test('Given no background, When inactive then resumed, Then onResumed is '
      'not called', () {
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(calls, 0);
  });

  test('Given the app went hidden, When resumed, Then onResumed is called '
      'once', () {
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(calls, 1);
  });

  test('Given the app went paused, When resumed, Then onResumed is called '
      'once', () {
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(calls, 1);
  });

  test('Given a handled resume, When resumed again without backgrounding, '
      'Then onResumed is not called again', () {
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(calls, 1);
  });
}
