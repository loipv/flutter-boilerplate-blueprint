import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

/// Application-wide error contract.
///
/// Every repository maps backend-specific exceptions to one of these variants.
/// `FirebaseException`, `DioException`, etc. must never leak past the data layer.
@freezed
abstract class Failure with _$Failure {
  const factory Failure.network([String? message]) = NetworkFailure;
  const factory Failure.cache([String? message]) = CacheFailure;
  const factory Failure.auth([String? message]) = AuthFailure;
  const factory Failure.server([String? message]) = ServerFailure;
  const factory Failure.permission([String? message]) = PermissionFailure;
  const factory Failure.unknown([String? message]) = UnknownFailure;
}
