import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:__APP_PACKAGE__/core/errors/failure.dart';
import 'package:__APP_PACKAGE__/core/utils/app_logger.dart';
import 'package:__APP_PACKAGE__/core/theme/theme_provider.dart';
import 'package:__APP_PACKAGE__/features/auth/data/firebase_auth_repository.dart';
import 'package:__APP_PACKAGE__/features/auth/domain/user_entity.dart';
import 'package:__APP_PACKAGE__/features/onboarding/application/onboarding_controller.dart';
import 'package:__APP_PACKAGE__/features/user_profile/data/firebase_user_repository.dart';

part 'auth_controller.g.dart';

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  static const _log = AppLogger('AuthController');

  @override
  Stream<UserEntity?> build() {
    return ref.watch(authRepositoryProvider).authStateChanges();
  }

  Future<void> signInAnonymously({String? name}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await ref
          .read(authRepositoryProvider)
          .signInAnonymously(name: name);
      await ref
          .read(userRepositoryProvider)
          .recordLogin(user.id, signInProvider: 'anonymous');
      return user;
    });
  }

  Future<void> signInWithGoogle() async {
    await _signInAndMigrate(
      () => ref.read(authRepositoryProvider).signInWithGoogle(),
    );
  }

  Future<void> signInWithApple() async {
    await _signInAndMigrate(
      () => ref.read(authRepositoryProvider).signInWithApple(),
    );
  }

  Future<void> _signInAndMigrate(
    Future<UserEntity> Function() signInMethod,
  ) async {
    final previousUser = state.value;

    // Only transition to loading for fresh sign-ins (no prior session).
    // When upgrading an existing anonymous session, let the sheet manage
    // its own loading state; setting loading here would cause the router
    // to flash the splash screen.
    if (previousUser == null) {
      state = const AsyncValue.loading();
    }

    try {
      final newUser = await signInMethod();

      // Migrate preferences if the user switched from anonymous to OAuth
      // (UIDs differ; linking keeps the same UID)
      if (previousUser != null &&
          previousUser.isAnonymous &&
          !newUser.isAnonymous &&
          previousUser.id != newUser.id) {
        await ref
            .read(userRepositoryProvider)
            .savePreferences(newUser.id, previousUser.preferences);
      }

      // Sync OAuth display name to Firestore
      final name = newUser.displayName;
      if (!newUser.isAnonymous && name != null && name.isNotEmpty) {
        await ref
            .read(userRepositoryProvider)
            .updateProfile(newUser.id, name: name);
      }

      await ref
          .read(userRepositoryProvider)
          .recordLogin(newUser.id, signInProvider: newUser.signInProvider);

      state = AsyncValue.data(newUser);
    } catch (e, st) {
      // Restore previous user so the router does not redirect to FTUX
      if (previousUser != null) {
        _log.warning('Sign-in failed; restoring previous session: $e');
        state = AsyncValue.data(previousUser);
      } else {
        state = AsyncValue.error(e, st);
      }
      // Swallow user-cancelled dialog; rethrow everything else
      final isCanceled =
          e is Failure &&
          e.maybeWhen(auth: (msg) => msg == 'canceled', orElse: () => false);
      if (!isCanceled) rethrow;
    }
  }

  /// Permanently deletes the account and all associated Firestore data.
  /// Returns `null` on success, or a user-facing error message on failure.
  Future<String?> deleteAccount() async {
    final user = state.value;
    if (user == null) return 'No signed-in user.';

    try {
      await ref.read(userRepositoryProvider).deleteUserData(user.id);

      try {
        await ref.read(authRepositoryProvider).deleteAuthAccount();
      } on Failure catch (e) {
        final needsReauth = e.maybeWhen(
          auth: (code) => code == 'requires-recent-login',
          orElse: () => false,
        );
        if (!needsReauth) rethrow;

        if (user.isAnonymous) {
          _log.warning(
            'deleteAccount: anonymous session cannot re-auth; skipping',
          );
        } else {
          await ref.read(authRepositoryProvider).reauthenticateForDeletion();
          await ref.read(authRepositoryProvider).deleteAuthAccount();
        }
      }

      await ref.read(onboardingControllerProvider.notifier).resetOnboarding();
      await ref.read(themeNotifierProvider.notifier).resetToSystem();
      return null;
    } catch (e) {
      if (e is Failure) {
        return e.maybeWhen(
          auth: (_) => 'Authentication error. Please try again.',
          orElse: () => 'Something went wrong. Please try again.',
        );
      }
      return 'Something went wrong. Please try again.';
    }
  }

  Future<void> updateDisplayName(String name) async {
    await ref.read(authRepositoryProvider).updateDisplayName(name);
    final uid = ref.read(authRepositoryProvider).currentUser?.id;
    if (uid != null) {
      await ref.read(userRepositoryProvider).updateProfile(uid, name: name);
    }
  }

  Future<void> signOut() async {
    await ref.read(onboardingControllerProvider.notifier).resetOnboarding();
    await ref.read(themeNotifierProvider.notifier).resetToSystem();
    await ref.read(authRepositoryProvider).signOut();
  }
}
