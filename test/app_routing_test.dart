import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/app.dart';
import 'package:vocably/models/app_user.dart';
import 'package:vocably/models/learning_progress.dart';
import 'package:vocably/models/learning_session.dart';
import 'package:vocably/models/target_word_set.dart';
import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/providers/auth_providers.dart';
import 'package:vocably/providers/dashboard_providers.dart';
import 'package:vocably/providers/history_providers.dart';
import 'package:vocably/providers/vocab_bundle_providers.dart';
import 'package:vocably/screens/auth/complete_registration_screen.dart';
import 'package:vocably/screens/auth/login_screen.dart';
import 'package:vocably/screens/student/dashboard/dashboard_screen.dart';
import 'package:vocably/screens/student/history/history_screen.dart';
import 'package:vocably/screens/student/placement_test/placement_test_offer_screen.dart';
import 'package:vocably/screens/teacher/target_words/target_words_placeholder.dart';
import 'package:vocably/screens/teacher/vocab_management/tambah_kosakata_screen.dart';
import 'package:vocably/services/target_word_set_service.dart';
import 'package:vocably/services/vocab_bundle_service.dart';
import 'package:vocably/services/learning_progress_service.dart';
import 'package:vocably/services/learning_session_service.dart';
import 'package:vocably/utils/role.dart';
import 'package:vocably/widgets/app_nav_shell.dart';

/// `DashboardScreen`/`HistoryScreen` (Milestone 6) hit real Firestore-
/// backed providers as soon as they build — these no-op fakes stand in so
/// routing tests never touch Firebase, mirroring the fakes
/// `dashboard_screen_test.dart`/`history_screen_test.dart` use for the
/// same providers.
class _NoopTargetWordSetService extends TargetWordSetService {
  @override
  Future<List<TargetWordSet>> fetchActiveForStudent(String studentId) async => [];
}

class _NoopVocabBundleService extends VocabBundleService {
  @override
  Future<List<VocabBundleEntry>> loadLevelWithDelta({
    required String cefrLevel,
    required DateTime bundleGeneratedAt,
  }) async => [];
}

class _NoopLearningProgressService extends LearningProgressService {
  @override
  Future<List<LearningProgress>> fetchForStudent(String studentId) async => [];
}

class _NoopLearningSessionService extends LearningSessionService {
  @override
  Future<List<LearningSession>> fetchForStudent(String studentId) async => [];
}

/// Stage 5 (Milestone 3) routing tests: `_RootRouter`'s `AppAuthSignedIn`
/// branch now returns `AppNavShell` with role-appropriate destinations,
/// instead of the retired `StudentPlaceholder`/`TeacherPlaceholder`
/// screens. `_RootRouter` itself is private and can't be reached directly
/// from this file, so — following the same pattern `test/widget_test.dart`
/// already relies on (Riverpod overrides, no real Firebase) — these tests
/// override [appAuthStatusProvider] directly and pump the real
/// [VocablyApp], exercising the actual routing switch end to end.
void main() {
  // `placementTestPrompted: true` — a student who has already seen the
  // one-time offer (Milestone 6, `SPEC.md` §3.1) routes straight to
  // AppNavShell. The `false`/unprompted case has its own group below.
  final studentProfile = AppUser(
    uid: 'student-1',
    email: 'siswa@example.com',
    name: 'Siswa Uji',
    role: Role.siswa,
    createdAt: DateTime(2026, 1, 1),
    placementTestPrompted: true,
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
        overrides: [
          appAuthStatusProvider.overrideWith((ref) => status),
          // DashboardScreen/HistoryScreen (Milestone 6) read live Firestore-
          // backed providers as soon as they build — see this file's
          // doc comment on the fakes above.
          targetWordSetServiceProvider.overrideWithValue(_NoopTargetWordSetService()),
          vocabBundleServiceProvider.overrideWithValue(_NoopVocabBundleService()),
          learningProgressServiceProvider.overrideWithValue(_NoopLearningProgressService()),
          learningSessionServiceProvider.overrideWithValue(_NoopLearningSessionService()),
        ],
        child: const VocablyApp(),
      ),
    );
    // Deliberately a plain pump(), not pumpAndSettle() — the loading-state
    // group below renders an indefinitely-animating CircularProgressIndicator,
    // which pumpAndSettle() would hang waiting to finish. One pump is
    // enough for every assertion in this file: they check which *widget
    // type* got built (DashboardScreen/AppNavShell/etc.), not the resolved
    // contents of any async provider inside it.
    await tester.pump();
  }

  group('signed-in student (already prompted for placement test)', () {
    testWidgets('routes to AppNavShell with Belajar + Riwayat only', (tester) async {
      await pumpWithStatus(tester, AppAuthSignedIn(studentProfile));

      expect(find.byType(AppNavShell), findsOneWidget);
      expect(find.text('Belajar'), findsWidgets);
      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.text('Target Kata'), findsNothing);
      expect(find.text('Kosakata'), findsNothing);

      // Belajar is the first destination, so its body (only) is built.
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(HistoryScreen), findsNothing);
      expect(find.byType(TargetWordsPlaceholder), findsNothing);
      expect(find.byType(TambahKosakataScreen), findsNothing);
      expect(find.byType(PlacementTestOfferScreen), findsNothing);
    });
  });

  group('signed-in student (never prompted for placement test)', () {
    testWidgets(
      'shows the one-time placement-test offer instead of the nav shell',
      (tester) async {
        final unpromptedProfile = AppUser(
          uid: 'student-2',
          email: 'siswa2@example.com',
          name: 'Siswa Baru',
          role: Role.siswa,
          createdAt: DateTime(2026, 1, 1),
          placementTestPrompted: false,
        );

        await pumpWithStatus(tester, AppAuthSignedIn(unpromptedProfile));

        expect(find.byType(PlacementTestOfferScreen), findsOneWidget);
        expect(find.byType(AppNavShell), findsNothing);
      },
    );

    testWidgets('a null placementTestPrompted (defensive case) also shows the offer', (
      tester,
    ) async {
      final noFieldProfile = AppUser(
        uid: 'student-3',
        email: 'siswa3@example.com',
        name: 'Siswa Lama',
        role: Role.siswa,
        createdAt: DateTime(2026, 1, 1),
        // placementTestPrompted intentionally omitted (null).
      );

      await pumpWithStatus(tester, AppAuthSignedIn(noFieldProfile));

      expect(find.byType(PlacementTestOfferScreen), findsOneWidget);
      expect(find.byType(AppNavShell), findsNothing);
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
      expect(find.byType(TambahKosakataScreen), findsNothing);
      expect(find.byType(DashboardScreen), findsNothing);
      expect(find.byType(HistoryScreen), findsNothing);
      // Guru is never offered the placement test, regardless of the field.
      expect(find.byType(PlacementTestOfferScreen), findsNothing);
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
