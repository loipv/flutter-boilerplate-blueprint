import 'dart:async';

import 'package:blueprint_app/features/auth/data/firebase_auth_repository.dart';
import 'package:blueprint_app/features/auth/domain/user_entity.dart';
import 'package:blueprint_app/features/auth/domain/user_preferences.dart';
import 'package:blueprint_app/features/user_profile/data/firebase_user_repository.dart';

/// In-memory auth repository for widget and app tests.
///
/// [authStateChanges] replays the current user to each new listener, then
/// emits every later change. Methods no test needs yet throw
/// [UnimplementedError].
class FakeAuthRepository implements FirebaseAuthRepository {
  FakeAuthRepository({UserEntity? initialUser}) : _user = initialUser;

  static const anonymousUser = UserEntity(
    id: 'anon-1',
    isAnonymous: true,
    signInProvider: 'anonymous',
  );

  UserEntity? _user;
  final _changes = StreamController<UserEntity?>.broadcast();

  void _emit(UserEntity? user) {
    _user = user;
    _changes.add(user);
  }

  @override
  UserEntity? get currentUser => _user;

  @override
  Stream<UserEntity?> authStateChanges() {
    return Stream.multi((controller) {
      controller.add(_user);
      final sub = _changes.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<UserEntity> signInAnonymously({String? name}) async {
    final user = (name == null || name.isEmpty)
        ? anonymousUser
        : anonymousUser.copyWith(displayName: name);
    _emit(user);
    return user;
  }

  @override
  Future<void> signOut() async => _emit(null);

  @override
  Future<UserEntity> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<UserEntity> signInWithApple() => throw UnimplementedError();

  @override
  Future<void> updateDisplayName(String name) => throw UnimplementedError();

  @override
  Future<void> deleteAuthAccount() => throw UnimplementedError();

  @override
  Future<void> reauthenticateForDeletion() => throw UnimplementedError();
}

/// In-memory user repository. Documents live in [users]; every call is
/// appended to [calls] as `'<method>:<uid>'`.
class FakeUserRepository implements FirebaseUserRepository {
  final Map<String, UserEntity> users = {};
  final List<String> calls = [];
  final _changes = StreamController<String>.broadcast();

  void _write(String uid, UserEntity Function(UserEntity) update) {
    users[uid] = update(users[uid] ?? UserEntity(id: uid));
    _changes.add(uid);
  }

  @override
  Stream<UserEntity?> getUserStream(String uid) {
    calls.add('getUserStream:$uid');
    return Stream.multi((controller) {
      controller.add(users[uid]);
      final sub = _changes.stream
          .where((changed) => changed == uid)
          .listen((_) => controller.add(users[uid]));
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> savePreferences(String uid, UserPreferences prefs) async {
    calls.add('savePreferences:$uid');
    _write(uid, (u) => u.copyWith(preferences: prefs));
  }

  @override
  Future<void> recordLogin(String uid, {String? signInProvider}) async {
    calls.add('recordLogin:$uid');
    _write(
      uid,
      (u) => u.copyWith(
        signInProvider: signInProvider ?? u.signInProvider,
        totalSessionCount: u.totalSessionCount + 1,
      ),
    );
  }

  @override
  Future<void> updateProfile(String uid, {String? name}) async {
    calls.add('updateProfile:$uid');
    if (name == null) return;
    _write(uid, (u) => u.copyWith(displayName: name));
  }

  @override
  Future<void> markOnboardingComplete(String uid) async {
    calls.add('markOnboardingComplete:$uid');
  }

  @override
  Future<void> deleteUserData(String uid) async {
    calls.add('deleteUserData:$uid');
    users.remove(uid);
    _changes.add(uid);
  }

  @override
  Future<void> updateLastAccessed(String uid) async {
    calls.add('updateLastAccessed:$uid');
  }
}
