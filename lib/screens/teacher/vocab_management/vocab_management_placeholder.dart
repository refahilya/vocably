import 'package:flutter/material.dart';

/// Placeholder body for the "Kosakata" navigation destination.
///
/// Milestone 3 Stage 4 only — no `Scaffold`/`AppBar` here, since
/// `AppNavShell` owns those once it's wired in (Stage 5). No logout
/// button: per the decided design, logout stays only on the primary
/// destination (Target Kata). Replaced by real vocabulary management
/// (`CLAUDE.md` §3/§7 — "Tambah Kosakata" in Milestone 5, "Edit Kata" in
/// Milestone 8) later.
class VocabManagementPlaceholder extends StatelessWidget {
  const VocabManagementPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Kosakata',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            '(Placeholder Milestone 3 — manajemen kosakata asli menyusul '
            'di Milestone 5 & 8.)',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
