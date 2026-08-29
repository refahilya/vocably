import 'package:flutter/material.dart';

import '../../../theme/theme.dart';

/// Placement Test scaffold body (`SPEC.md` §3.1, `DESIGN_REFERENCE.md`
/// §5.2) — reachable both from the one-time automatic offer
/// ([PlacementTestOfferScreen]'s "Mulai Tes") and from the permanent
/// entry point in the dashboard's "Level" card.
///
/// **Deliberately one screen, not the two ("body" / "hasil") §5.2
/// sketches.** Those are two states of an actual test *in progress* — but
/// the scoring method and question set are still fully TBD
/// (`CLAUDE.md` §10, `SPEC.md` §3.1), so nothing in this milestone can
/// ever produce a transition from "taking the test" to "here's your
/// result". Building an unreachable second screen for a result nothing
/// can generate yet would be dead code, not scaffolding — when the
/// instrument is decided, this screen splits into the real
/// body-then-result flow §5.2 describes.
class PlacementTestPlaceholderScreen extends StatelessWidget {
  const PlacementTestPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tes Penempatan')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top, size: 48, color: AppColors.disabled),
              SizedBox(height: AppSpacing.md),
              Text(
                'Tes penempatan akan segera hadir',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'Soal dan cara penilaian tes ini masih disusun. Kamu tetap '
                'bisa memilih level dan belajar kosakata sekarang lewat menu '
                'Level.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
