import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/firebase_status_provider.dart';

/// Root widget of the Vocably app.
///
/// Milestone 1 scope: this only hosts a temporary connection-check screen.
/// Real navigation (student/teacher shell, see CLAUDE.md §5/§6) starts in
/// Milestone 3.
class VocablyApp extends StatelessWidget {
  const VocablyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocably',
      debugShowCheckedModeBanner: false,
      home: const _ConnectionCheckScreen(),
    );
  }
}

/// Milestone 1 placeholder screen.
///
/// Proves Firebase (`firebase_core`/`firebase_auth`/`cloud_firestore`) and
/// the Riverpod code-generation pipeline work end-to-end. Replaced by the
/// real dashboard/auth screens starting Milestone 2/3.
class _ConnectionCheckScreen extends ConsumerWidget {
  const _ConnectionCheckScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(firebaseStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Vocably')),
      body: Center(
        child: status.when(
          data: (value) => switch (value) {
            FirebaseStatus.ready => const _StatusMessage(
              icon: Icons.check_circle,
              color: Colors.green,
              message: 'Firebase connected',
            ),
            FirebaseStatus.failed => const _StatusMessage(
              icon: Icons.error,
              color: Colors.red,
              message: 'Firebase failed to initialize',
            ),
          },
          loading: () => const CircularProgressIndicator(),
          error: (error, stackTrace) => _StatusMessage(
            icon: Icons.error,
            color: Colors.red,
            message: 'Firebase failed to initialize: $error',
          ),
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 48),
        const SizedBox(height: 12),
        Text(message),
      ],
    );
  }
}
