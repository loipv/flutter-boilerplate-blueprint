import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:__APP_PACKAGE__/core/data/posthog_analytics_repository.dart';
import 'package:__APP_PACKAGE__/core/domain/analytics_repository.dart';
import 'package:__APP_PACKAGE__/core/errors/failure.dart';
import 'package:__APP_PACKAGE__/core/utils/app_logger.dart';
import 'package:__APP_PACKAGE__/features/auth/domain/auth_repository.dart';
import 'package:__APP_PACKAGE__/features/auth/domain/user_entity.dart';

part 'firebase_auth_repository.g.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._firebaseAuth, this._analytics);

  final FirebaseAuth _firebaseAuth;
  final AnalyticsRepository _analytics;
  static const _log = AppLogger('FirebaseAuthRepository');

  // ---------------------------------------------------------------------------
  // Auth state
  // ---------------------------------------------------------------------------

  @override
  Stream<UserEntity?> authStateChanges() {
    // Prepend the synchronous currentUser to eliminate the brief null gap that
    // Firebase Auth emits before reading the persisted token from Keychain /
    // SharedPreferences. Without this, the router briefly flashes onboarding
    // for returning signed-in users on cold start.
    final current = _firebaseAuth.currentUser;
    final downstream = _firebaseAuth.authStateChanges().map(
      (u) => u?.toEntity(),
    );

    if (current == null) return downstream;

    return Stream.multi((controller) {
      controller.add(current.toEntity());
      final sub = downstream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  UserEntity? get currentUser => _firebaseAuth.currentUser?.toEntity();

  // ---------------------------------------------------------------------------
  // Sign-in methods
  // ---------------------------------------------------------------------------

  @override
  Future<UserEntity> signInAnonymously({String? name}) async {
    try {
      final credential = await _firebaseAuth.signInAnonymously();
      final user = credential.user!;
      if (name != null && name.isNotEmpty) {
        await user.updateDisplayName(name);
        await user.reload();
      }
      return _firebaseAuth.currentUser!.toEntity();
    } on FirebaseAuthException catch (e) {
      _log.error('Anonymous sign-in failed', error: e);
      throw Failure.auth(e.message);
    } catch (e, st) {
      _log.error(
        'Anonymous sign-in unexpected error',
        error: e,
        stackTrace: st,
      );
      throw Failure.unknown(e.toString());
    }
  }

  @override
  Future<UserEntity> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: null,
        idToken: googleAuth.idToken,
      );
      final entity = await _signInWithCredential(credential);

      // Sync displayName if Firebase doesn't have it yet
      if (entity.displayName == null &&
          googleUser.displayName != null &&
          googleUser.displayName!.isNotEmpty) {
        await _firebaseAuth.currentUser?.updateDisplayName(
          googleUser.displayName,
        );
        await _firebaseAuth.currentUser?.reload();
      }
      return _firebaseAuth.currentUser!.toEntity();
    } on FirebaseAuthException catch (e) {
      _log.error('Google sign-in failed', error: e);
      throw Failure.auth(e.code);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const Failure.auth('canceled');
      }
      _log.warning('Google sign-in unavailable: $e');
      throw Failure.unknown(e.toString());
    } catch (e, st) {
      _log.error('Google sign-in unexpected error', error: e, stackTrace: st);
      throw Failure.unknown(e.toString());
    }
  }

  @override
  Future<UserEntity> signInWithApple() async {
    if (Platform.isAndroid) return _signInWithAppleWeb();

    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final identityToken = appleCredential.identityToken;
      if (identityToken == null) throw const Failure.auth('apple-unavailable');

      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: identityToken,
        // authorizationCode is required for Firebase's server-side token exchange
        // with Apple during linkWithCredential. Without it, linking fails with
        // invalid-credential instead of the expected credential-already-in-use.
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );

      await _signInWithCredential(credential);

      // Apple only provides fullName on the first sign-in
      final fullName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ].where((n) => n != null && n.isNotEmpty).join(' ');
      if (fullName.isNotEmpty) {
        await _firebaseAuth.currentUser?.updateDisplayName(fullName);
        await _firebaseAuth.currentUser?.reload();
      }

      return _firebaseAuth.currentUser!.toEntity();
    } on FirebaseAuthException catch (e) {
      _log.error('Apple sign-in failed', error: e);
      throw Failure.auth(e.code);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const Failure.auth('canceled');
      }
      if (e.code == AuthorizationErrorCode.unknown) {
        // Error 1000 (ASAuthorizationErrorUnknown): device has no Apple ID
        // configured, MDM restriction, or Sign in with Apple unavailable.
        _log.warning('Apple sign-in unavailable (error 1000): $e');
        throw const Failure.auth('apple-unavailable');
      }
      _log.warning('Apple authorization error: $e');
      throw Failure.unknown(e.toString());
    } catch (e, st) {
      if (e is Failure) rethrow;
      _log.error('Apple sign-in unexpected error', error: e, stackTrace: st);
      throw Failure.unknown(e.toString());
    }
  }

  Future<UserEntity> _signInWithAppleWeb() async {
    final provider = OAuthProvider('apple.com')
      ..addScope('email')
      ..addScope('name');
    try {
      final currentUser = _firebaseAuth.currentUser;
      late UserCredential userCredential;
      if (currentUser != null && currentUser.isAnonymous) {
        try {
          userCredential = await currentUser.linkWithProvider(provider);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            // Same Apple account already linked to a different UID — sign into
            // that existing account directly.
            userCredential = await _firebaseAuth.signInWithProvider(provider);
          } else if (e.code == 'email-already-in-use') {
            // Email belongs to an account on a different provider (e.g. Google).
            _log.warning(
              'Apple web sign-in: email already used by a different provider',
            );
            throw const Failure.auth('email-already-in-use');
          } else {
            _log.error('Apple web link failed', error: e);
            throw Failure.auth(e.message);
          }
        }
      } else {
        userCredential = await _firebaseAuth.signInWithProvider(provider);
      }
      return userCredential.user!.toEntity();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'web-context-cancelled' ||
          e.code == 'cancelled-popup-request' ||
          e.code == 'user-cancelled') {
        throw const Failure.auth('canceled');
      }
      throw Failure.auth(e.message);
    } on Failure {
      rethrow;
    } catch (e, st) {
      _log.error('Apple web sign-in error', error: e, stackTrace: st);
      throw Failure.unknown(e.toString());
    }
  }

  Future<UserEntity> _signInWithCredential(AuthCredential credential) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser != null && currentUser.isAnonymous) {
      try {
        final uc = await currentUser.linkWithCredential(credential);
        return uc.user!.toEntity();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'invalid-credential' ||
            e.code == 'user-not-found' ||
            e.code == 'invalid-user-token' ||
            e.code == 'user-token-expired') {
          // Firebase provides a fresh credential via e.credential (FlutterFire PR #11889)
          final fallback = e.credential ?? credential;
          final uc = await _firebaseAuth.signInWithCredential(fallback);
          return uc.user!.toEntity();
        }
        if (e.code == 'email-already-in-use')
          throw const Failure.auth('email-already-in-use');
        throw Failure.auth(e.code);
      }
    } else {
      final uc = await _firebaseAuth.signInWithCredential(credential);
      return uc.user!.toEntity();
    }
  }

  // ---------------------------------------------------------------------------
  // Account management
  // ---------------------------------------------------------------------------

  @override
  Future<void> updateDisplayName(String name) async {
    try {
      await _firebaseAuth.currentUser?.updateDisplayName(name);
      await _firebaseAuth.currentUser?.reload();
    } on FirebaseAuthException catch (e) {
      throw Failure.auth(e.message);
    }
  }

  @override
  Future<void> deleteAuthAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw const Failure.auth('No signed-in user');
      await user.delete();
    } on FirebaseAuthException catch (e) {
      _log.error('deleteAuthAccount failed', error: e);
      throw Failure.auth(e.code);
    }
  }

  @override
  Future<void> reauthenticateForDeletion() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const Failure.auth('No signed-in user');

    final providerIds = user.providerData.map((p) => p.providerId).toList();

    try {
      if (providerIds.contains('google.com')) {
        final googleUser = await GoogleSignIn.instance.authenticate();
        final googleAuth = googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
      } else if (providerIds.contains('apple.com')) {
        final rawNonce = _generateNonce();
        final nonce = _sha256ofString(rawNonce);
        final apple = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
        );
        final credential = OAuthProvider('apple.com').credential(
          idToken: apple.identityToken,
          accessToken: apple.authorizationCode,
          rawNonce: rawNonce,
        );
        await user.reauthenticateWithCredential(credential);
      } else {
        throw const Failure.auth('unsupported-provider');
      }
    } on FirebaseAuthException catch (e) {
      throw Failure.auth(e.code);
    } catch (e, st) {
      if (e is Failure) rethrow;
      _log.error('reauthenticate failed', error: e, stackTrace: st);
      throw Failure.unknown(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await Future.wait([
        _firebaseAuth.signOut(),
        GoogleSignIn.instance.signOut(),
      ]);
      await _analytics.reset();
    } on FirebaseAuthException catch (e) {
      throw Failure.auth(e.message);
    } catch (e, st) {
      _log.error('Sign-out failed', error: e, stackTrace: st);
      throw Failure.unknown(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}

extension on User {
  UserEntity toEntity() {
    final providers = providerData.map((p) => p.providerId).toSet();
    final signInProvider = providers.contains('apple.com')
        ? 'apple'
        : providers.contains('google.com')
        ? 'google'
        : isAnonymous
        ? 'anonymous'
        : null;

    return UserEntity(
      id: uid,
      email: email,
      displayName: displayName,
      signInProvider: signInProvider,
      isAnonymous: isAnonymous,
      createdAt: metadata.creationTime,
      lastLoginAt: metadata.lastSignInTime,
    );
  }
}

@Riverpod(keepAlive: true)
FirebaseAuthRepository authRepository(Ref ref) {
  return FirebaseAuthRepository(
    FirebaseAuth.instance,
    ref.read(analyticsRepositoryProvider),
  );
}
