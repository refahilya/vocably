import 'package:flutter/material.dart';

import '../models/learning_progress.dart';
import '../theme/theme.dart';

/// The small mastery-status dot from `DESIGN_REFERENCE.md` §5.3 — "dot
/// kecil berwarna di pojok kiri atas chip/card": green = `mastered`,
/// amber = `difficult`, nothing rendered at all for `belum_dipelajari`
/// ("tanpa penanda supaya UI tetap bersih untuk kata yang belum
/// disentuh"). Reusable wherever a word chip/card needs this — first used
/// by Riwayat (Milestone 6), intended for the vocab browser too whenever
/// that screen is revisited.
class MasteryBadge extends StatelessWidget {
  const MasteryBadge({super.key, required this.masteryStatus});

  /// One of [MasteryStatus], or `null` for "not learned yet" (renders
  /// nothing).
  final String? masteryStatus;

  @override
  Widget build(BuildContext context) {
    final color = switch (masteryStatus) {
      MasteryStatus.mastered => AppColors.success,
      MasteryStatus.difficult => AppColors.masteryDifficult,
      _ => null,
    };

    if (color == null) return const SizedBox.shrink();

    return Semantics(
      label: masteryStatus == MasteryStatus.mastered ? 'Mastered' : 'Difficult',
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
