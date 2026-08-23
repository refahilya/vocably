import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../providers/auth_providers.dart';

/// Milestone 2 placeholder — proves role-based routing landed a `guru`
/// account here, and provides a logout action. Replaced by the real
/// teacher dashboard in Milestone 8.
class TeacherPlaceholder extends ConsumerWidget {
  const TeacherPlaceholder({super.key, required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vocably — Guru')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Selamat datang, ${profile.name}'),
            const SizedBox(height: 8),
            const Text(
              '(Placeholder Milestone 2 — dashboard guru asli\n'
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
      ),
    );
  }
}
