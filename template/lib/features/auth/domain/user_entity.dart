import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:__APP_PACKAGE__/features/auth/domain/user_preferences.dart';

part 'user_entity.freezed.dart';
part 'user_entity.g.dart';

@freezed
abstract class UserEntity with _$UserEntity {
  const UserEntity._();

  const factory UserEntity({
    required String id,
    String? email,
    String? displayName,

    /// 'apple' | 'google' | 'anonymous' | null
    String? signInProvider,
    @Default(false) bool isAnonymous,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    DateTime? lastAccessedAt,
    @Default(0) int totalSessionCount,
    @Default(UserPreferences()) UserPreferences preferences,
    // TODO: add domain-specific fields here, e.g.:
    // @Default([]) List<String> savedItemIds,
    // @Default(false) bool isPro,
  }) = _UserEntity;

  factory UserEntity.fromJson(Map<String, dynamic> json) =>
      _$UserEntityFromJson(json);

  bool get isSignedIn => !isAnonymous;
}
