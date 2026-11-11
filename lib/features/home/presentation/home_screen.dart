import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:blueprint_app/core/theme/app_spacing.dart';
import 'package:blueprint_app/core/theme/app_typography.dart';
// BEGIN_ADS
import 'package:blueprint_app/features/ads/presentation/ad_banner.dart';
// END_ADS

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home', style: AppTypography.titleLarge),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.p4),
                child: _HomeBody(),
              ),
            ),
            // BEGIN_ADS
            const AdBanner(),
            // END_ADS
          ],
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Welcome', style: AppTypography.headlineMedium),
          const Gap(AppSpacing.p2),
          Text(
            'Your home screen content goes here.',
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
