import 'package:flutter/material.dart';

/// Shown at cold start while auth and onboarding state are being resolved.
///
/// Background color and logo deliberately match the native LaunchScreen so the
/// hand-off from the native splash to this Flutter widget is seamless.
///
/// Replace `assets/icons/app_logo.png` with your own logo (1024×1024 PNG).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  // Must match the `flutter_native_splash` color in pubspec.yaml.
  static const _splashBackground = Color(__SPLASH_BG__);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _splashBackground,
      body: Center(
        child: Image.asset(
          'assets/icons/app_logo.png',
          width: 120,
          height: 120,
        ),
      ),
    );
  }
}
