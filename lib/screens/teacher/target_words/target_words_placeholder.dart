import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../providers/auth_providers.dart';

/// Placeholder body for the "Target Kata" navigation destination.
///
/// Milestone 3 Stage 4 only splits the old `TeacherPlaceholder` screen
/// (which owned its own `Scaffold`/`AppBar`) into per-destination bodies —
/// no `Scaffold`/`AppBar` here, since `AppNavShell` owns those once it's
/// wired in (Stage 5). This is where teacher target-word management lands
/// (`CLAUDE.md` §7 Milestone 8); for now it only proves the destination
/// and its logout action.
class TargetWordsPlaceholder extends ConsumerWidget {
  const TargetWordsPlaceholder({super.key, required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Target Kata',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Selamat datang, ${profile.name}'),
          const SizedBox(height: 8),
          const Text(
            '(Placeholder Milestone 3 — pengaturan target kata asli '
            'menyusul di Milestone 8.)',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => ref.read(authServiceProvider).signOut(),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}
