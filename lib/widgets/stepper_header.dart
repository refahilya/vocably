import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_layout.dart';

/// The 3-phase stepper shown on all three Storyfier screens
/// (`DESIGN_REFERENCE.md` §3.1): "Membaca — Cloze Test — Co-Write".
/// One reusable widget, per that section's explicit instruction ("Jadikan
/// satu widget reusable... bukan re-implementasi per layar") — used
/// identically by all three entry points (Target Kata Hari Ini, Keranjang
/// Pelajari, Pelajari Kembali all run the same 3 phases, so there is no
/// "2-phase" variant, per that same section's note).
///
/// It continues the navy app bar, so the header reads as one band, and the
/// active step takes the highlighter.
class StepperHeader extends StatelessWidget {
  const StepperHeader({super.key, required this.activeIndex});

  /// 0 = Membaca, 1 = Cloze Test, 2 = Co-Write. Steps before this index
  /// render as completed (check); this one renders as active (highlighter,
  /// bold); steps after render as upcoming (pale outline).
  final int activeIndex;

  static const _labels = ['Membaca', 'Cloze Test', 'Co-Write'];

  /// Below this width the connectors stop stretching and the row may scale.
  static const double _compactWidth = 420;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary,
      child: AppContent(
        maxWidth: AppContentWidth.reading,
        vertical: AppSpacing.sm + 2,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < _compactWidth;
            final row = Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                for (var i = 0; i < _labels.length; i++) ...[
                  if (i > 0)
                    compact
                        ? SizedBox(width: 32, child: _connector(i))
                        : Expanded(child: _connector(i)),
                  _StepDot(
                    label: _labels[i],
                    number: i + 1,
                    state: _stateFor(i),
                  ),
                ],
              ],
            );
            // All three labels stay readable on the smallest phones, even with
            // large text: the row scales down instead of overflowing.
            return compact
                ? FittedBox(fit: BoxFit.scaleDown, child: row)
                : row;
          },
        ),
      ),
    );
  }

  Widget _connector(int index) => Container(
    height: 2,
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    color: index <= activeIndex
        ? AppColors.marker
        : AppColors.onNavyMuted.withAlpha(90),
  );

  _StepState _stateFor(int index) {
    if (index < activeIndex) return _StepState.completed;
    if (index == activeIndex) return _StepState.active;
    return _StepState.upcoming;
  }
}

enum _StepState { completed, active, upcoming }

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.number,
    required this.state,
  });

  final String label;
  final int number;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final isActive = state == _StepState.active;
    final isCompleted = state == _StepState.completed;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? AppColors.marker
                : (isCompleted ? Colors.white : Colors.transparent),
            border: isActive || isCompleted
                ? null
                : Border.all(color: AppColors.onNavyMuted),
          ),
          child: isCompleted
              ? const Icon(Icons.check, size: 14, color: AppColors.primary)
              : Text(
                  '$number',
                  style: AppTextStyles.badgeLabel.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? AppColors.primaryDeep
                        : AppColors.onNavyMuted,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.badgeLabel.copyWith(
            color: isActive ? Colors.white : AppColors.onNavyMuted,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
