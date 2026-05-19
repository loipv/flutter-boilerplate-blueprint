import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:__APP_PACKAGE__/core/theme/app_spacing.dart';
import 'package:__APP_PACKAGE__/core/theme/app_typography.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Explore', style: AppTypography.titleLarge),
        centerTitle: false,
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.p4),
          child: _ExploreBody(),
        ),
      ),
    );
  }
}

class _ExploreBody extends ConsumerWidget {
  const _ExploreBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Explore', style: AppTypography.headlineMedium),
          const Gap(AppSpacing.p2),
          Text(
            'Your explore / discovery content goes here.',
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
