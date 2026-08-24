import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_providers.dart';
import 'screens/auth/complete_registration_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/placeholders/student_placeholder.dart';
import 'screens/placeholders/teacher_placeholder.dart';
import 'theme/theme.dart';
import 'utils/role.dart';

/// Root widget of the Vocably app.
class VocablyApp extends StatelessWidget {
  const VocablyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocably',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const _RootRouter(),
    );
  }
}

/// Milestone 2 root routing: switches on [appAuthStatusProvider].
///
/// Milestone 2 scope only — the destinations below (other than the auth
/// screens themselves) are still temporary placeholders (see CLAUDE.md
/// §7). The responsive navigation shell (Milestone 3) and real dashboards
/// (Milestone 6/8) replace them later. Deliberately no routing package —
/// plain Navigator.push is used for the login/sign-up toggle, per project
/// decision.
class _RootRouter extends ConsumerWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(appAuthStatusProvider);

    return switch (status) {
      AppAuthLoading() => const _LoadingScreen(),
      AppAuthSignedOut() => const LoginScreen(),
      AppAuthNeedsProfile(:final uid, :final email) =>
        CompleteRegistrationScreen(uid: uid, email: email),
      AppAuthSignedIn(:final profile) => profile.role == Role.guru
          ? TeacherPlaceholder(profile: profile)
          : StudentPlaceholder(profile: profile),
    };
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
