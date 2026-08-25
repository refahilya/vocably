import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../providers/auth_providers.dart';
import '../vocab_browser/vocab_browser_screen.dart';

/// Placeholder body for the "Belajar" navigation destination.
///
/// Milestone 3 Stage 4 only splits the old `StudentPlaceholder` screen
/// (which owned its own `Scaffold`/`AppBar`) into per-destination bodies —
/// no `Scaffold`/`AppBar` here, since `AppNavShell` owns those once it's
/// wired in (Stage 5). This is where the real student dashboard (two
/// cards: Target Kata Hari Ini, Level — `CLAUDE.md` §7 Milestone 6) lands
/// later; for now it only proves the destination and its logout action.
class DashboardPlaceholder extends ConsumerWidget {
  const DashboardPlaceholder({super.key, required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Belajar',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Selamat datang, ${profile.name}'),
          const SizedBox(height: 8),
          const Text(
            '(Placeholder Milestone 3 — dashboard siswa asli menyusul di '
            'Milestone 6.)',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // TODO(Milestone 6): TEMPORARY entry point for Milestone 4 Stage
          // 5's vocabulary browse screen. The real navigation into browse
          // is the "Level" card's 6 CEFR pills (DESIGN_REFERENCE.md §5.1),
          // which doesn't exist until Milestone 6 builds the real
          // dashboard here. Remove this button (and this import) once
          // that card replaces this whole placeholder.
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VocabBrowserScreen()),
            ),
            child: const Text('Jelajahi Kosakata (Sementara)'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => ref.read(authServiceProvider).signOut(),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}
