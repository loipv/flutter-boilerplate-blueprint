import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ad_free_provider.g.dart';

/// Whether the current user has opted out of ads (for example by purchase).
///
/// Defaults to false. Override it from a purchase provider:
///
/// ```dart
/// adFreeProvider.overrideWith(
///   (ref) => ref.watch(purchaseProvider).value?.isPremium ?? false,
/// )
/// ```
@Riverpod(keepAlive: true)
bool adFree(Ref ref) => false;
