import 'package:flutter/material.dart';

import '../models/learning_progress.dart';
import '../theme/theme.dart';

/// The small mastery-status mark from `DESIGN_REFERENCE.md` §5.3: green =
/// `mastered`, amber = `difficult`, nothing rendered at all for
/// `belum_dipelajari` ("tanpa penanda supaya UI tetap bersih untuk kata yang
/// belum disentuh"). The two states differ in shape as well as color, so they
/// stay distinct for color-blind students.
class MasteryBadge extends StatelessWidget {
  const MasteryBadge({super.key, required this.masteryStatus});

  /// One of [MasteryStatus], or `null` for "not learned yet" (renders
  /// nothing).
  final String? masteryStatus;

  @override
  Widget build(BuildContext context) {
    final (color, shape) = switch (masteryStatus) {
      MasteryStatus.mastered => (AppColors.success, BoxShape.circle),
      MasteryStatus.difficult => (AppColors.masteryDifficult, BoxShape.rectangle),
      _ => (null, BoxShape.circle),
    };

    if (color == null) return const SizedBox.shrink();

    return Semantics(
      label: masteryStatus == MasteryStatus.mastered ? 'Mastered' : 'Difficult',
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: color,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(2)
              : null,
        ),
      ),
    );
  }
}
