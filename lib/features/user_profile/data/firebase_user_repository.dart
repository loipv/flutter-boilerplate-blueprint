import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:blueprint_app/core/constants/app_constants.dart';
import 'package:blueprint_app/core/errors/failure.dart';
import 'package:blueprint_app/core/utils/app_logger.dart';
import 'package:blueprint_app/features/auth/domain/user_entity.dart';
import 'package:blueprint_app/features/auth/domain/user_preferences.dart';
import 'package:blueprint_app/features/user_profile/domain/user_repository.dart';

part 'firebase_user_repository.g.dart';

class FirebaseUserRepository implements UserRepository {
  FirebaseUserRepository(this._firestore);

  final FirebaseFirestore _firestore;
  static const _log = AppLogger('FirebaseUserRepository');

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection(AppConstants.usersCollection).doc(uid);

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  @override
  Stream<UserEntity?> getUserStream(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      try {
        return UserEntity.fromJson({'id': uid, ...snap.data()!});
      } catch (e, st) {
        _log.error('Failed to parse user document', error: e, stackTrace: st);
        return null;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  @override
  Future<void> savePreferences(String uid, UserPreferences prefs) async {
    try {
      await _userDoc(
        uid,
      ).set({'preferences': prefs.toJson()}, SetOptions(merge: true));
    } catch (e, st) {
      _log.error('savePreferences failed', error: e, stackTrace: st);
      throw const Failure.server();
    }
  }

  @override
  Future<void> recordLogin(String uid, {String? signInProvider}) async {
    try {
      await _userDoc(uid).set({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'totalSessionCount': FieldValue.increment(1),
        'signInProvider': ?signInProvider,
      }, SetOptions(merge: true));
    } catch (e, st) {
      _log.error('recordLogin failed', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> updateProfile(String uid, {String? name}) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['displayName'] = name;
      if (updates.isEmpty) return;
      await _userDoc(uid).set(updates, SetOptions(merge: true));
    } catch (e, st) {
      _log.error('updateProfile failed', error: e, stackTrace: st);
      throw const Failure.server();
    }
  }

  @override
  Future<void> markOnboardingComplete(String uid) async {
    try {
      await _userDoc(
        uid,
      ).set({'onboardingCompleted': true}, SetOptions(merge: true));
    } catch (e, st) {
      _log.error('markOnboardingComplete failed', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> deleteUserData(String uid) async {
    try {
      await _userDoc(uid).delete();
    } catch (e, st) {
      _log.error('deleteUserData failed', error: e, stackTrace: st);
      throw const Failure.server();
    }
  }

  @override
  Future<void> updateLastAccessed(String uid) async {
    try {
      await _userDoc(uid).set({
        'lastAccessedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      _log.error('updateLastAccessed failed', error: e, stackTrace: st);
    }
  }
}

@Riverpod(keepAlive: true)
FirebaseUserRepository userRepository(Ref ref) {
  return FirebaseUserRepository(FirebaseFirestore.instance);
}
