import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:blueprint_app/core/data/firebase_remote_config_repository.dart';
import 'package:blueprint_app/core/domain/config_keys.dart';

part 'ads_master_switch_provider.g.dart';

/// The Remote Config master switch `ads_enabled`, read once per app launch.
///
/// Deliberately not reactive: a value fetched mid-session is ignored until the
/// app restarts, so ads never switch on or off (and the consent form and ATT
/// prompt never appear) in the middle of a session. The per-format keys stay
/// reactive.
@Riverpod(keepAlive: true)
bool adsMasterSwitch(Ref ref) =>
    ref.read(remoteConfigRepositoryProvider).get(ConfigKeys.adsEnabled);
