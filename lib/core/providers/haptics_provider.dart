import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:blueprint_app/features/user_profile/application/user_profile_providers.dart';

part 'haptics_provider.g.dart';

/// Synchronously reflects the user's haptics preference.
/// Defaults to `true` while the profile stream is loading or on error.
///
/// Kept alive because `AppHaptics` only reads it. Reads alone do not keep
/// the profile stream delivering (Riverpod 3 pauses providers with no
/// listener), so `App` also listens to it for the app's lifetime.
@Riverpod(keepAlive: true)
bool hapticsEnabled(Ref ref) {
  return ref
          .watch(userProfileStreamProvider)
          .value
          ?.preferences
          .hapticsEnabled ??
      true;
}
