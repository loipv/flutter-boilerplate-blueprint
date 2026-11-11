import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blueprint_app/features/ads/application/ads_enabled_provider.dart';
import 'package:blueprint_app/features/ads/application/ads_settings.dart';
import 'package:blueprint_app/features/ads/data/google_mobile_ads_repository.dart';
import 'package:blueprint_app/features/ads/domain/ad_banner_handle.dart';
import 'package:blueprint_app/features/ads/domain/ad_format.dart';

/// An adaptive banner ad. Renders nothing until an ad has loaded, and nothing
/// while ads are off.
class AdBanner extends ConsumerStatefulWidget {
  const AdBanner({super.key});

  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner> {
  AdBannerHandle? _handle;
  bool _loading = false;

  /// Bumped on every reset so a late load result can be told apart.
  int _generation = 0;

  @override
  void dispose() {
    _generation++;
    _handle?.dispose();
    _handle = null;
    super.dispose();
  }

  void _release() {
    _generation++;
    _loading = false;
    final handle = _handle;
    _handle = null;
    handle?.dispose();
  }

  Future<void> _load(double width) async {
    final unitId = ref.read(adsSettingsProvider).unitId(AdFormat.banner);
    if (unitId == null || !_isEnabled) return;
    _loading = true;
    final generation = _generation;
    var handled = false;
    try {
      final handle = await ref
          .read(adsRepositoryProvider)
          .loadBanner(adUnitId: unitId, width: width);
      if (handle == null) return;
      if (!mounted || generation != _generation || !_isEnabled) {
        handle.dispose();
        return;
      }
      handled = true;
      setState(() {
        _handle = handle;
        _loading = false;
      });
    } finally {
      if (!handled && mounted && generation == _generation) _loading = false;
    }
  }

  bool get _isEnabled => ref.read(adsEnabledProvider(AdFormat.banner));

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(adsEnabledProvider(AdFormat.banner));
    ref.listen(adsEnabledProvider(AdFormat.banner), (_, next) {
      if (next || !mounted) return;
      if (_handle == null && !_loading) return;
      setState(_release);
    });

    if (!enabled) return const SizedBox.shrink();

    final handle = _handle;
    if (handle != null) {
      return SizedBox.fromSize(size: handle.size, child: handle.widget);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!_loading && width.isFinite && width > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_loading && _handle == null) _load(width);
          });
        }
        return const SizedBox.shrink();
      },
    );
  }
}
