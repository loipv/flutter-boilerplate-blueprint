import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:blueprint_app/core/data/firebase_remote_config_repository.dart';
import 'package:blueprint_app/core/domain/config_key.dart';

part 'remote_config_revision_provider.g.dart';

/// Counts Remote Config updates. Starts at 0 and increments on every
/// `onUpdated` event, so anything that watches it recomputes after a fetch.
///
/// Not wrapped in REMOTE_CONFIG markers: when the SDK is stripped the
/// repository never emits and the revision stays 0.
@Riverpod(keepAlive: true)
class RemoteConfigRevision extends _$RemoteConfigRevision {
  @override
  int build() {
    final sub = ref
        .watch(remoteConfigRepositoryProvider)
        .onUpdated
        .listen((_) => state++);
    ref.onDispose(sub.cancel);
    return 0;
  }
}

/// Reactive config read for providers.
extension RemoteConfigRef on Ref {
  /// Watches the revision first so the caller recomputes after an update,
  /// then reads the current value from the repository.
  T watchConfig<T extends Object>(ConfigKey<T> key) {
    watch(remoteConfigRevisionProvider);
    return read(remoteConfigRepositoryProvider).get(key);
  }
}

/// Reactive config read for widgets.
extension RemoteConfigWidgetRef on WidgetRef {
  /// Watches the revision first so the widget rebuilds after an update,
  /// then reads the current value from the repository.
  T watchConfig<T extends Object>(ConfigKey<T> key) {
    watch(remoteConfigRevisionProvider);
    return read(remoteConfigRepositoryProvider).get(key);
  }
}
