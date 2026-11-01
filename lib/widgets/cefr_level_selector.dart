import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../utils/cefr_levels.dart';

/// A single-choice row of CEFR levels. It wraps rather than scrolls, so all
/// six levels stay visible and reachable on a 320px phone.
class CefrLevelSelector extends StatelessWidget {
  const CefrLevelSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final level in kCefrLevels)
          ChoiceChip(
            label: Text(level),
            selected: level == selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(level),
          ),
      ],
    );
  }
}
