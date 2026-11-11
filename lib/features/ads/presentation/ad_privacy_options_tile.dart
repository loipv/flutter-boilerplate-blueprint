import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:blueprint_app/core/l10n/l10n_extension.dart';
import 'package:blueprint_app/core/theme/app_spacing.dart';
import 'package:blueprint_app/features/ads/application/ads_consent_controller.dart';

/// Settings tile that re-opens the ad privacy options form. Renders nothing
/// unless the consent flow says the form must be offered.
class AdPrivacyOptionsTile extends ConsumerWidget {
  const AdPrivacyOptionsTile({super.key, required this.header});

  final Widget header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final required =
        ref.watch(adsConsentControllerProvider).value?.privacyOptionsRequired ==
        true;
    if (!required) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(AppSpacing.p4),
        header,
        ListTile(
          leading: const Icon(LucideIcons.shieldCheck),
          title: Text(context.l10n.adsPrivacyOptions),
          subtitle: Text(context.l10n.adsManageConsent),
          onTap: () => ref
              .read(adsConsentControllerProvider.notifier)
              .showPrivacyOptions(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}
