import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:__APP_PACKAGE__/features/user_profile/application/user_profile_providers.dart';

part 'haptics_provider.g.dart';

/// Synchronously reflects the user's haptics preference.
/// Defaults to `true` while the profile stream is loading or on error.
@riverpod
bool hapticsEnabled(Ref ref) {
  return ref
          .watch(userProfileStreamProvider)
          .value
          ?.preferences
          .hapticsEnabled ??
      true;
}
