/// Firestore collection names and app-wide constants.
///
/// Centralising these prevents string typos and makes renaming easy.
abstract class AppConstants {
  // Firestore collections
  static const String usersCollection = 'users';

  // TODO: add your domain collection names here, e.g.:
  // static const String postsCollection = 'posts';
  // static const String commentsCollection = 'comments';

  // SharedPreferences keys
  static const String onboardingCompleteKey = 'onboarding_complete';

  // App
  static const String appName = '__APP_TITLE__';
}
