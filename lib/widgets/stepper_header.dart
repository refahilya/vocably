import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The 3-phase stepper shown on all three Storyfier screens
/// (`DESIGN_REFERENCE.md` §3.1): "● Membaca — ○ Cloze Test — ○ Co-Write".
/// One reusable widget, per that section's explicit instruction ("Jadikan
/// satu widget reusable... bukan re-implementasi per layar") — used
/// identically by all three entry points (Target Kata Hari Ini, Keranjang
/// Pelajari, Pelajari Kembali all run the same 3 phases, so there is no
/// "2-phase" variant, per that same section's note).
class StepperHeader extends StatelessWidget {
  const StepperHeader({super.key, required this.activeIndex});

  /// 0 = Membaca, 1 = Cloze Test, 2 = Co-Write. Steps before this index
  /// render as completed (check); this one renders as active (filled,
  /// bold); steps after render as upcoming (pale outline).
  final int activeIndex;

  static const _labels = ['Membaca', 'Cloze Test', 'Co-Write'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            if (i > 0) const Expanded(child: Divider(color: Colors.white38, height: 1)),
            _StepDot(label: _labels[i], state: _stateFor(i)),
          ],
        ],
      ),
    );
  }

  _StepState _stateFor(int index) {
    if (index < activeIndex) return _StepState.completed;
    if (index == activeIndex) return _StepState.active;
    return _StepState.upcoming;
  }
}

enum _StepState { completed, active, upcoming }

class _StepDot extends StatelessWidget {
  const _StepDot({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final isActive = state == _StepState.active;
    final isCompleted = state == _StepState.completed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isCompleted ? Colors.white : Colors.transparent,
            border: Border.all(color: Colors.white, width: isActive ? 2 : 1),
          ),
          child: isCompleted
              ? const Icon(Icons.check, size: 14, color: AppColors.primary)
              : null,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
