import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/app.dart';
import 'package:vocably/models/app_user.dart';
import 'package:vocably/providers/auth_providers.dart';
import 'package:vocably/screens/auth/complete_registration_screen.dart';
import 'package:vocably/screens/auth/login_screen.dart';
import 'package:vocably/screens/student/dashboard/dashboard_placeholder.dart';
import 'package:vocably/screens/student/history/history_placeholder.dart';
import 'package:vocably/screens/teacher/target_words/target_words_placeholder.dart';
import 'package:vocably/screens/teacher/vocab_management/vocab_management_placeholder.dart';
import 'package:vocably/utils/role.dart';
import 'package:vocably/widgets/app_nav_shell.dart';

/// Stage 5 (Milestone 3) routing tests: `_RootRouter`'s `AppAuthSignedIn`
/// branch now returns `AppNavShell` with role-appropriate destinations,
/// instead of the retired `StudentPlaceholder`/`TeacherPlaceholder`
/// screens. `_RootRouter` itself is private and can't be reached directly
/// from this file, so — following the same pattern `test/widget_test.dart`
/// already relies on (Riverpod overrides, no real Firebase) — these tests
/// override [appAuthStatusProvider] directly and pump the real
/// [VocablyApp], exercising the actual routing switch end to end.
void main() {
  final studentProfile = AppUser(
    uid: 'student-1',
    email: 'siswa@example.com',
    name: 'Siswa Uji',
    role: Role.siswa,
    createdAt: DateTime(2026, 1, 1),
  );

  final teacherProfile = AppUser(
    uid: 'teacher-1',
    email: 'guru@example.com',
    name: 'Guru Uji',
    role: Role.guru,
    createdAt: DateTime(2026, 1, 1),
  );

  Future<void> pumpWithStatus(WidgetTester tester, AppAuthStatus status) async {
    // Wide surface so the shell renders NavigationRail deterministically —
    // responsive behavior itself is already covered by
    // test/widgets/app_nav_shell_test.dart; this file only cares about
    // which destinations got wired in for which role.
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appAuthStatusProvider.overrideWith((ref) => status)],
        child: const VocablyApp(),
      ),
    );
    await tester.pump();
  }

  group('signed-in student', () {
    testWidgets('routes to AppNavShell with Belajar + Riwayat only', (tester) async {
      await pumpWithStatus(tester, AppAuthSignedIn(studentProfile));

      expect(find.byType(AppNavShell), findsOneWidget);
      expect(find.text('Belajar'), findsWidgets);
      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.text('Target Kata'), findsNothing);
      expect(find.text('Kosakata'), findsNothing);

      // Belajar is the first destination, so its body (only) is built.
      expect(find.byType(DashboardPlaceholder), findsOneWidget);
      expect(find.byType(HistoryPlaceholder), findsNothing);
      expect(find.byType(TargetWordsPlaceholder), findsNothing);
      expect(find.byType(VocabManagementPlaceholder), findsNothing);
    });
  });

  group('signed-in teacher', () {
    testWidgets('routes to AppNavShell with Target Kata + Kosakata only', (tester) async {
      await pumpWithStatus(tester, AppAuthSignedIn(teacherProfile));

      expect(find.byType(AppNavShell), findsOneWidget);
      expect(find.text('Target Kata'), findsWidgets);
      expect(find.text('Kosakata'), findsOneWidget);
      expect(find.text('Belajar'), findsNothing);
      expect(find.text('Riwayat'), findsNothing);

      // Target Kata is the first destination, so its body (only) is built.
      expect(find.byType(TargetWordsPlaceholder), findsOneWidget);
      expect(find.byType(VocabManagementPlaceholder), findsNothing);
      expect(find.byType(DashboardPlaceholder), findsNothing);
      expect(find.byType(HistoryPlaceholder), findsNothing);
    });
  });

  group('other auth states are unchanged by Stage 5', () {
    testWidgets('loading state still shows a loading indicator, not the shell', (
      tester,
    ) async {
      await pumpWithStatus(tester, const AppAuthLoading());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AppNavShell), findsNothing);
    });

    testWidgets('signed-out state still shows LoginScreen, not the shell', (tester) async {
      await pumpWithStatus(tester, const AppAuthSignedOut());

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AppNavShell), findsNothing);
    });

    testWidgets('needs-profile state still shows CompleteRegistrationScreen, not the shell', (
      tester,
    ) async {
      await pumpWithStatus(
        tester,
        const AppAuthNeedsProfile(uid: 'orphan-1', email: 'orphan@example.com'),
      );

      expect(find.byType(CompleteRegistrationScreen), findsOneWidget);
      expect(find.byType(AppNavShell), findsNothing);
    });
  });
}
