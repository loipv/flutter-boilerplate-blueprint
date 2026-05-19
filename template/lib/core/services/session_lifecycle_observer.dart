import 'package:flutter/widgets.dart';
import 'package:__APP_PACKAGE__/core/utils/app_logger.dart';
import 'package:__APP_PACKAGE__/features/auth/domain/user_entity.dart';
import 'package:__APP_PACKAGE__/features/user_profile/domain/user_repository.dart';

/// Records `lastAccessedAt` and increments `totalSessionCount` in Firestore
/// every time the app returns to the foreground.
///
/// Register in `App.initState()`:
/// ```dart
/// _sessionObserver = SessionLifecycleObserver(
///   getRepository: () => ref.read(userRepositoryProvider),
///   getCurrentUser: () => ref.read(authControllerProvider).value,
/// );
/// WidgetsBinding.instance.addObserver(_sessionObserver!);
/// ```
class SessionLifecycleObserver extends WidgetsBindingObserver {
  SessionLifecycleObserver({
    required this.getRepository,
    required this.getCurrentUser,
  });

  final UserRepository Function() getRepository;
  final UserEntity? Function() getCurrentUser;

  static const _log = AppLogger('SessionLifecycleObserver');

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recordSession();
    }
  }

  Future<void> _recordSession() async {
    try {
      final user = getCurrentUser();
      if (user == null) return;
      await getRepository().updateLastAccessed(user.id);
    } catch (e, st) {
      _log.error('Failed to record session', error: e, stackTrace: st);
    }
  }
}
