import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_user.dart';
import 'providers/auth_providers.dart';
import 'screens/auth/complete_registration_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/dashboard/dashboard_placeholder.dart';
import 'screens/student/history/history_placeholder.dart';
import 'screens/teacher/target_words/target_words_placeholder.dart';
import 'screens/teacher/vocab_management/vocab_management_placeholder.dart';
import 'theme/theme.dart';
import 'utils/role.dart';
import 'widgets/app_nav_shell.dart';

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

/// Root routing: switches on [appAuthStatusProvider].
///
/// Once signed in, the destination bodies inside [AppNavShell] are still
/// placeholders — real dashboards land in Milestones 5/6/8 (see
/// `CLAUDE.md` §7). Deliberately no routing package — plain
/// Navigator.push is used for the login/sign-up toggle, per project
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
      AppAuthSignedIn(:final profile) => AppNavShell(
        destinations: profile.role == Role.guru
            ? _teacherDestinations(profile)
            : _studentDestinations(profile),
      ),
    };
  }
}

/// Destinations for a signed-in `siswa`: Belajar (dashboard, Milestone 6)
/// and Riwayat (learning history, Milestone 6) — see `CLAUDE.md` §7. This
/// role→destinations mapping is the routing layer's job, not
/// `AppNavShell`'s (see that file's own doc comment).
List<AppNavDestination> _studentDestinations(AppUser profile) {
  return [
    AppNavDestination(
      label: 'Belajar',
      icon: Icons.school,
      body: DashboardPlaceholder(profile: profile),
    ),
    const AppNavDestination(
      label: 'Riwayat',
      icon: Icons.history,
      body: HistoryPlaceholder(),
    ),
  ];
}

/// Destinations for a signed-in `guru`: Target Kata (Milestone 8) and
/// Kosakata (vocabulary management, Milestone 5 & 8) — see `CLAUDE.md` §7.
List<AppNavDestination> _teacherDestinations(AppUser profile) {
  return [
    AppNavDestination(
      label: 'Target Kata',
      icon: Icons.track_changes,
      body: TargetWordsPlaceholder(profile: profile),
    ),
    const AppNavDestination(
      label: 'Kosakata',
      icon: Icons.menu_book,
      body: VocabManagementPlaceholder(),
    ),
  ];
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
