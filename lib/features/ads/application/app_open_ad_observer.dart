import 'package:flutter/widgets.dart';

/// Calls [onResumed] each time the app returns to the foreground.
class AppOpenAdObserver extends WidgetsBindingObserver {
  AppOpenAdObserver({required Future<bool> Function() onResumed})
    : _onResumed = onResumed;

  final Future<bool> Function() _onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResumed();
  }
}
