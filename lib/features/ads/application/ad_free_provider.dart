import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ad_free_provider.g.dart';

/// Whether the current user has opted out of ads (for example by purchase).
///
/// Defaults to false. Override it from a purchase provider. Treat "still
/// loading" as ad-free (`?? true`) so consent and ATT do not run before the
/// purchase state is known:
///
/// ```dart
/// adFreeProvider.overrideWith(
///   (ref) => ref.watch(purchaseProvider).value?.isPremium ?? true,
/// )
/// ```
@Riverpod(keepAlive: true)
bool adFree(Ref ref) => false;
