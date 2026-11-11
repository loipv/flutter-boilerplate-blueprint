import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:blueprint_app/features/auth/domain/user_entity.dart';
import 'package:blueprint_app/features/auth/domain/user_preferences.dart';

void main() {
  group('UserEntity defaults', () {
    test('Given only an id, When constructed, Then defaults apply', () {
      const user = UserEntity(id: 'u1');

      expect(user.isAnonymous, isFalse);
      expect(user.totalSessionCount, 0);
      expect(user.preferences, const UserPreferences());
      expect(user.email, isNull);
    });
  });

  group('toJson / fromJson', () {
    test('Given a full entity, When round-tripped, Then it is equal', () {
      final user = UserEntity(
        id: 'u1',
        email: 'a@b.co',
        displayName: 'Ann',
        signInProvider: 'google',
        createdAt: DateTime.utc(2026, 1, 1),
        lastLoginAt: DateTime.utc(2026, 1, 2),
        lastAccessedAt: DateTime.utc(2026, 1, 3),
        totalSessionCount: 5,
      );

      // jsonEncode drives toJson() on the nested preferences, as in production.
      final json =
          jsonDecode(jsonEncode(user.toJson())) as Map<String, dynamic>;

      expect(UserEntity.fromJson(json), user);
    });
  });

  group('isSignedIn', () {
    test('Given a non-anonymous user, When read, Then it is true', () {
      expect(const UserEntity(id: 'u1').isSignedIn, isTrue);
    });

    test('Given an anonymous user, When read, Then it is false', () {
      expect(const UserEntity(id: 'u1', isAnonymous: true).isSignedIn, isFalse);
    });
  });
}
