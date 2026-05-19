import 'package:__APP_PACKAGE__/features/auth/domain/user_entity.dart';
import 'package:__APP_PACKAGE__/features/auth/domain/user_preferences.dart';

/// Backend-agnostic contract for user profile data in Firestore.
///
/// The concrete implementation is `FirebaseUserRepository` in `data/`.
abstract class UserRepository {
  /// Streams the user document. Emits `null` if the document doesn't exist yet.
  Stream<UserEntity?> getUserStream(String uid);

  /// Writes preferences (themeMode, hapticsEnabled, etc.) to the user document.
  Future<void> savePreferences(String uid, UserPreferences prefs);

  /// Records a login event; increments session count and writes lastLoginAt.
  Future<void> recordLogin(String uid, {String? signInProvider});

  /// Updates the display name in the Firestore profile.
  Future<void> updateProfile(String uid, {String? name});

  /// Marks the onboarding flow as complete in the user document.
  Future<void> markOnboardingComplete(String uid);

  /// Deletes the entire user Firestore document. Call before deleteAuthAccount.
  Future<void> deleteUserData(String uid);

  /// Writes `lastAccessedAt`; called on every app foreground transition.
  Future<void> updateLastAccessed(String uid);
}
