import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:__APP_PACKAGE__/features/auth/application/auth_controller.dart';
import 'package:__APP_PACKAGE__/features/auth/domain/user_entity.dart';
import 'package:__APP_PACKAGE__/features/user_profile/data/firebase_user_repository.dart';

part 'user_profile_providers.g.dart';

/// The currently authenticated user entity, or `null` if not signed in.
///
/// Wraps `authControllerProvider` so consumers can watch a single provider
/// for the user identity without depending directly on auth internals.
@riverpod
AsyncValue<UserEntity?> currentUser(Ref ref) =>
    ref.watch(authControllerProvider);

/// Streams the current user's Firestore profile document.
/// Returns `null` when no user is signed in or the document doesn't exist yet.
@riverpod
Stream<UserEntity?> userProfileStream(Ref ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(userRepositoryProvider).getUserStream(user.id);
}
