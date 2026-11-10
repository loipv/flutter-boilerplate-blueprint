# UI / UX Design System

## Fonts

Two typefaces, both bundled in `assets/fonts/` (no remote fetching).

| Family        | Weights                                                                   | Usage                |
| ------------- | ------------------------------------------------------------------------- | -------------------- |
| Inter         | Regular 400, Medium 500, SemiBold 600, Bold 700, ExtraBold 800, Black 900 | All body and UI text |
| JetBrainsMono | Medium 500                                                                | Code / monospace     |

Always reference via `AppTypography`:

```dart
Text('Hello', style: AppTypography.titleLarge(context))
Text('body', style: AppTypography.bodyMedium(context))
```

Never use `google_fonts` or hardcode font family strings directly.

## Type Scale (`AppTypography`)

| Method           | Size | Weight             | Use              |
| ---------------- | ---- | ------------------ | ---------------- |
| `displayLarge`   | 57   | Bold               | Hero / splash    |
| `displayMedium`  | 45   | Bold               | Feature titles   |
| `headlineLarge`  | 32   | SemiBold           | Screen titles    |
| `headlineMedium` | 28   | SemiBold           | Section headings |
| `titleLarge`     | 22   | SemiBold           | AppBar titles    |
| `titleMedium`    | 16   | SemiBold           | Card titles      |
| `titleSmall`     | 14   | SemiBold           | List item titles |
| `bodyLarge`      | 16   | Regular            | Primary body     |
| `bodyMedium`     | 14   | Regular            | Secondary body   |
| `bodySmall`      | 12   | Regular            | Captions         |
| `labelLarge`     | 14   | Medium             | Buttons          |
| `labelMedium`    | 12   | Medium             | Tags, chips      |
| `labelSmall`     | 11   | Medium             | Timestamps       |
| `mono`           | 13   | Medium (JetBrains) | Code, IPA        |

## Colors

Defined in `core/theme/app_colors.dart`. All values come from the scaffold questionnaire.

| Token                    | Usage                            |
| ------------------------ | -------------------------------- |
| `AppColors.primaryLight` | Primary brand color (light mode) |
| `AppColors.primaryDark`  | Primary brand color (dark mode)  |
| `AppColors.accent`       | Accent / highlight color         |
| `AppColors.bgLight`      | Background (light mode)          |
| `AppColors.bgDark`       | Background (dark mode)           |

Contextual helpers (prefer these in widgets):

```dart
AppColors.textSecondary(context)   // onSurfaceVariant
AppColors.textTertiary(context)    // onSurfaceVariant at 60% opacity
```

\*\*Never use `Color.withOpacity()`. Use `Color.withValues(alpha: 0.x)` instead..

## Spacing (`AppSpacing`)

All spacing uses the `Gap` widget with `AppSpacing` constants:

```dart
const Gap(AppSpacing.p1)   // 4px
const Gap(AppSpacing.p2)   // 8px
const Gap(AppSpacing.p3)   // 12px
const Gap(AppSpacing.p4)   // 16px
const Gap(AppSpacing.p5)   // 20px
const Gap(AppSpacing.p6)   // 24px
const Gap(AppSpacing.p8)   // 32px
const Gap(AppSpacing.p10)  // 40px
const Gap(AppSpacing.p12)  // 48px
const Gap(AppSpacing.p16)  // 64px
```

\*\*Never use `SizedBox` for spacing. Use `Gap`..

## Icons

Use `lucide_icons_flutter` exclusively:

```dart
Icon(LucideIcons.house)
Icon(LucideIcons.settings)
Icon(LucideIcons.circleUserRound)
```

Never use Material Icons (`Icons.*`) or `phosphor_flutter`.

## Theme

`AppTheme.light()` and `AppTheme.dark()` generate `ThemeData` from `AppColors`. The active theme is driven by `themeModeProvider` (Riverpod) backed by SharedPreferences.

Users select theme in onboarding (ThemeSelectionView) and can change it in Settings.

## Haptics

```dart
AppHaptics.selectionClick(ref)   // tab / chip selection
AppHaptics.lightImpact(ref)      // button press
AppHaptics.mediumImpact(ref)     // confirmation
AppHaptics.heavyImpact(ref)      // destructive action
AppHaptics.success(ref)          // task completed
AppHaptics.error(ref)            // validation failure
```

All haptics are gated on `hapticsEnabledProvider`. Always pass `ref`. Never call `HapticFeedback.*` directly.

## Navigation

Bottom navigation uses Material 3 `NavigationBar` with:

- `indicatorColor`: primary at 12% opacity
- Selected label: `FontWeight.w600`, primary color
- Unselected label: `FontWeight.w500`, `onSurfaceVariant`
- Tab switch: 120ms fade via `AnimationController`

Tab icons are `LucideIcons`; see MainScaffold variants for 2/3/4 tab defaults.

## Widgets Conventions

- \*\*No `StatefulWidget`. Use `ConsumerWidget` / `ConsumerStatefulWidget`
- `ConsumerState.build()` signature: `Widget build(BuildContext context)` (no `WidgetRef` parameter)
- \*\*No `SizedBox` for spacing. Use `Gap(AppSpacing.pN)`.
- \*\*No relative imports. Absolute only (`package:app_package/...`)
- Prefer single-row layouts over stacked approaches; check for RenderFlex overflow

## Snack Bars

```dart
AppSnackBar.show(context, message: 'Saved');
AppSnackBar.showError(context, message: 'Something went wrong');
```

Never call `ScaffoldMessenger.of(context).showSnackBar(...)` directly.
