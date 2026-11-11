import 'dart:async';

import 'package:flutter/widgets.dart';

/// Calls [onResumed] when the app returns to the foreground after a genuine
/// trip to the background.
///
/// `inactive` -> `resumed` alone (system alerts, permission prompts, Control
/// Center) does not count.
class AppOpenAdObserver extends WidgetsBindingObserver {
  AppOpenAdObserver({required Future<bool> Function() onResumed})
    : _onResumed = onResumed;

  final Future<bool> Function() _onResumed;
  bool _backgrounded = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _backgrounded = true;
      case AppLifecycleState.resumed:
        if (!_backgrounded) return;
        _backgrounded = false;
        unawaited(_onResumed());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}
