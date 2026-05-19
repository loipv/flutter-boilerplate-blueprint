import 'package:__APP_PACKAGE__/features/auth/domain/user_entity.dart';

/// Backend-agnostic authentication contract.
///
/// Controllers and UI depend only on this interface, never on Firebase directly.
/// The concrete implementation is `FirebaseAuthRepository` in `data/`.
abstract class AuthRepository {
  /// Emits the current user on every auth-state change; `null` when signed out.
  Stream<UserEntity?> authStateChanges();

  /// Synchronously returns the currently signed-in user, or `null`.
  UserEntity? get currentUser;

  /// Creates (or resumes) an anonymous session.
  Future<UserEntity> signInAnonymously({String? name});

  /// Signs in via Google, linking/migrating from an anonymous account when applicable.
  Future<UserEntity> signInWithGoogle();

  /// Signs in via Apple, linking/migrating from an anonymous account when applicable.
  Future<UserEntity> signInWithApple();

  /// Updates the display name on the current user's Firebase Auth profile.
  Future<void> updateDisplayName(String name);

  /// Permanently deletes the Firebase Auth account.
  /// Throws [Failure.auth] with code `'requires-recent-login'` if the session
  /// is stale. Call [reauthenticateForDeletion] first, then retry.
  Future<void> deleteAuthAccount();

  /// Re-authenticates via the linked provider (Google or Apple).
  /// Required before retrying [deleteAuthAccount] on `requires-recent-login`.
  Future<void> reauthenticateForDeletion();

  /// Signs out of all providers and resets the analytics session.
  Future<void> signOut();
}
