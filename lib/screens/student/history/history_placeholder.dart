import 'package:flutter/material.dart';

/// Placeholder body for the "Riwayat" navigation destination.
///
/// Milestone 3 Stage 4 only — no `Scaffold`/`AppBar` here, since
/// `AppNavShell` owns those once it's wired in (Stage 5). No logout button:
/// per the decided design, logout stays only on the primary destination
/// (Belajar). Replaced by the real learning-history view
/// (`CLAUDE.md` §7 Milestone 6) later.
class HistoryPlaceholder extends StatelessWidget {
  const HistoryPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Riwayat',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            '(Placeholder Milestone 3 — riwayat belajar asli menyusul di '
            'Milestone 6.)',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
