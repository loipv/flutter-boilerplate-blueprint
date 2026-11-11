import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/features/ads/application/app_open_ad_observer.dart';

void main() {
  test('Given an observer, When lifecycle changes, Then only resumed calls '
      'onResumed', () {
    var calls = 0;
    final observer = AppOpenAdObserver(
      onResumed: () async {
        calls++;
        return true;
      },
    );

    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    expect(calls, 0);

    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(calls, 1);
  });
}
