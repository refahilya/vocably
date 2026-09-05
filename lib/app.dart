import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_user.dart';
import 'providers/auth_providers.dart';
import 'screens/auth/complete_registration_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/dashboard/dashboard_screen.dart';
import 'screens/student/history/history_screen.dart';
import 'screens/student/placement_test/placement_test_offer_screen.dart';
import 'screens/teacher/target_words/target_words_screen.dart';
import 'screens/teacher/vocab_management/vocab_management_screen.dart';
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
/// Siswa destinations (Belajar/Riwayat, Milestone 6) and guru destinations
/// (Target Kata/Kosakata, Milestone 8) are all real screens now (see
/// `CLAUDE.md` §7). Deliberately no routing package — plain Navigator.push
/// is used for the login/sign-up toggle and for screens pushed on top of a
/// nav-shell destination, per project decision.
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
      // Milestone 6 (`SPEC.md` §3.1): the one-time automatic placement-test
      // offer is shown in place of the nav shell for a signed-in student
      // whose `placementTestPrompted` isn't `true` yet — never for guru.
      // `!= true` (rather than `== false`) also catches a hypothetical
      // `null` the same way, since a real siswa document always has this
      // field explicitly `false` from `AppUser.newStudentData()`.
      AppAuthSignedIn(:final profile)
          when profile.isStudent && profile.placementTestPrompted != true =>
        PlacementTestOfferScreen(profile: profile),
      AppAuthSignedIn(:final profile) => AppNavShell(
        destinations: profile.role == Role.guru
            ? _teacherDestinations(profile)
            : _studentDestinations(profile),
        onLogout: () => ref.read(authServiceProvider).signOut(),
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
      body: DashboardScreen(profile: profile),
    ),
    AppNavDestination(
      label: 'Riwayat',
      icon: Icons.history,
      body: HistoryScreen(profile: profile),
    ),
  ];
}

/// Destinations for a signed-in `guru`: Target Kata (Milestone 8) and
/// Kosakata (vocabulary management — Tambah Kosakata & Edit Kata,
/// Milestone 8 — see `CLAUDE.md` §7).
List<AppNavDestination> _teacherDestinations(AppUser profile) {
  return [
    AppNavDestination(
      label: 'Target Kata',
      icon: Icons.track_changes,
      body: TargetWordsScreen(profile: profile),
    ),
    AppNavDestination(
      label: 'Kosakata',
      icon: Icons.menu_book,
      body: VocabManagementScreen(profile: profile),
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
