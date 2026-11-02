import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/app.dart';
import 'package:vocably/models/app_user.dart';
import 'package:vocably/models/placement_instrument.dart';
import 'package:vocably/models/placement_status.dart';
import 'package:vocably/models/target_word_set.dart';
import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/providers/auth_providers.dart';
import 'package:vocably/providers/dashboard_providers.dart';
import 'package:vocably/providers/placement_test_providers.dart';
import 'package:vocably/providers/research_assessment_providers.dart';
import 'package:vocably/providers/vocab_bundle_providers.dart';
import 'package:vocably/screens/auth/login_screen.dart';
import 'package:vocably/screens/auth/sign_up_screen.dart';
import 'package:vocably/screens/student/dashboard/dashboard_screen.dart';
import 'package:vocably/screens/student/placement_test/placement_instructions.dart';
import 'package:vocably/screens/student/placement_test/placement_test_offer_screen.dart';
import 'package:vocably/screens/student/placement_test/placement_test_screen.dart';
import 'package:vocably/services/research_assessment_service.dart';
import 'package:vocably/services/target_word_set_service.dart';
import 'package:vocably/services/user_service.dart';
import 'package:vocably/services/vocab_bundle_service.dart';
import 'package:vocably/utils/role.dart';

import 'support/fake_placement_service.dart';
import 'support/fake_research_assessment_service.dart';

/// Behaves as Firestore does: the local snapshot reaches the profile listener
/// first, and the write's future only completes once the server answers.
class _FirestoreLikeUserService extends UserService {
  _FirestoreLikeUserService(this.profile);

  final ValueNotifier<AppUser> profile;
  final serverAnswer = Completer<void>();
  final promptedUids = <String>[];

  @override
  Future<void> markPlacementTestPrompted(String uid) async {
    promptedUids.add(uid);
    profile.value = _student(prompted: true);
    await serverAnswer.future;
  }
}

class _RefusingUserService extends UserService {
  @override
  Future<void> markPlacementTestPrompted(String uid) async {
    throw Exception('permission-denied');
  }
}

class _NoTargets extends TargetWordSetService {
  @override
  Future<List<TargetWordSet>> fetchActiveForStudent(String studentId) async => [];
}

class _NoVocab extends VocabBundleService {
  @override
  Future<List<VocabBundleEntry>> loadLevelWithDelta({
    required String cefrLevel,
    required DateTime bundleGeneratedAt,
  }) async => [];
}

AppUser _student({required bool prompted}) => AppUser(
  uid: 'student-1',
  email: 'siswa@example.com',
  name: 'Siswa Baru',
  role: Role.siswa,
  createdAt: DateTime(2026, 1, 1),
  placementTestPrompted: prompted,
);

/// The real [VocablyApp] and root router, with the profile as a live value.
Future<void> _pumpApp(
  WidgetTester tester, {
  required ValueNotifier<AppUser> profile,
  required UserService userService,
  FakePlacementService? placementService,
}) async {
  addTearDown(profile.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appAuthStatusProvider.overrideWith((ref) {
          void rebuild() => ref.invalidateSelf();
          profile.addListener(rebuild);
          ref.onDispose(() => profile.removeListener(rebuild));
          return AppAuthSignedIn(profile.value);
        }),
        userServiceProvider.overrideWithValue(userService),
        placementServiceProvider.overrideWithValue(
          placementService ?? FakePlacementService(),
        ),
        researchAssessmentServiceProvider.overrideWithValue(
          FakeResearchAssessmentService(),
        ),
        targetWordSetServiceProvider.overrideWithValue(_NoTargets()),
        vocabBundleServiceProvider.overrideWithValue(_NoVocab()),
      ],
      child: const VocablyApp(),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(PlacementTestOfferScreen), findsOneWidget);
}

/// The real app from signed out, with the auth status as a live value.
Future<void> _pumpSignedOutApp(
  WidgetTester tester,
  ValueNotifier<AppAuthStatus> status,
) async {
  addTearDown(status.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appAuthStatusProvider.overrideWith((ref) {
          void rebuild() => ref.invalidateSelf();
          status.addListener(rebuild);
          ref.onDispose(() => status.removeListener(rebuild));
          return status.value;
        }),
        placementServiceProvider.overrideWithValue(FakePlacementService()),
        researchAssessmentServiceProvider.overrideWithValue(
          FakeResearchAssessmentService(),
        ),
        targetWordSetServiceProvider.overrideWithValue(_NoTargets()),
        vocabBundleServiceProvider.overrideWithValue(_NoVocab()),
      ],
      child: const VocablyApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// The tap, the snapshot that swaps the root screen, then the server's answer.
Future<void> _choose(
  WidgetTester tester,
  String label,
  _FirestoreLikeUserService service,
) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  service.serverAnswer.complete();
  await tester.pumpAndSettle();
}

void main() {
  group('reaching the offer', () {
    testWidgets('a new account leaves the sign-up form for the offer', (
      tester,
    ) async {
      final status = ValueNotifier<AppAuthStatus>(const AppAuthSignedOut());
      await _pumpSignedOutApp(tester, status);

      await tester.tap(find.text('Belum punya akun? Daftar'));
      await tester.pumpAndSettle();
      expect(find.byType(SignUpScreen), findsOneWidget);

      // Auth first, then the profile document, as a real sign-up lands.
      status.value = const AppAuthNeedsProfile(
        uid: 'student-1',
        email: 'siswa@example.com',
      );
      await tester.pumpAndSettle();
      expect(find.byType(SignUpScreen), findsOneWidget);

      status.value = AppAuthSignedIn(_student(prompted: false));
      await tester.pumpAndSettle();

      expect(find.byType(SignUpScreen), findsNothing);
      expect(find.byType(PlacementTestOfferScreen), findsOneWidget);
      expect(find.text('Mulai Tes'), findsOneWidget);
    });

    testWidgets('signing in from a pushed login clears every auth screen', (
      tester,
    ) async {
      final status = ValueNotifier<AppAuthStatus>(const AppAuthSignedOut());
      await _pumpSignedOutApp(tester, status);

      await tester.tap(find.text('Belum punya akun? Daftar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sudah punya akun? Masuk'));
      await tester.pumpAndSettle();

      status.value = AppAuthSignedIn(_student(prompted: true));
      await tester.pumpAndSettle();

      expect(find.byType(SignUpScreen), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('a sign-up that does not end signed in stays on the form', (
      tester,
    ) async {
      final status = ValueNotifier<AppAuthStatus>(const AppAuthSignedOut());
      await _pumpSignedOutApp(tester, status);

      await tester.tap(find.text('Belum punya akun? Daftar'));
      await tester.pumpAndSettle();

      // A refused teacher code rolls the Auth account back.
      status.value = const AppAuthNeedsProfile(
        uid: 'teacher-1',
        email: 'guru@example.com',
      );
      await tester.pumpAndSettle();
      status.value = const AppAuthSignedOut();
      await tester.pumpAndSettle();

      expect(find.byType(SignUpScreen), findsOneWidget);
    });
  });

  group('"Mulai Tes"', () {
    testWidgets('opens the Placement Test, and the offer is marked as seen', (
      tester,
    ) async {
      final profile = ValueNotifier(_student(prompted: false));
      final service = _FirestoreLikeUserService(profile);
      await _pumpApp(tester, profile: profile, userService: service);

      await _choose(tester, 'Mulai Tes', service);

      expect(find.byType(PlacementTestScreen), findsOneWidget);
      expect(find.text(kPlacementInstructionsTitle), findsOneWidget);
      expect(find.text('Mulai'), findsOneWidget);
      expect(service.promptedUids, ['student-1']);
      expect(profile.value.placementTestPrompted, isTrue);
    });

    testWidgets('leaving the test lands on the dashboard, not the offer', (
      tester,
    ) async {
      final profile = ValueNotifier(_student(prompted: false));
      final service = _FirestoreLikeUserService(profile);
      await _pumpApp(tester, profile: profile, userService: service);

      await _choose(tester, 'Mulai Tes', service);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(PlacementTestOfferScreen), findsNothing);
    });

    final unavailable = <String, (String, String, FakePlacementService Function())>{
      'not configured': (
        'Belum tersedia',
        'Tes penempatan belum tersedia.',
        () => FakePlacementService()..config = null,
      ),
      'closed for learning': (
        'Belum dibuka',
        'Tes penempatan sedang tidak dibuka. Coba lagi nanti.',
        () => FakePlacementService(
          config: const PlacementConfig(
            instrumentVersion: kPlacementInstrumentVersion,
            learningOpen: false,
          ),
        ),
      ),
      'unreachable': (
        'Gagal memuat tes',
        'Periksa koneksi internet, lalu coba lagi.',
        () => FakePlacementService()
          ..readFaults.add(ResearchFailureKind.unavailable),
      ),
    };
    unavailable.forEach((name, expected) {
      final (title, body, build) = expected;
      testWidgets('explains itself instead of the dashboard when $name', (
        tester,
      ) async {
        final profile = ValueNotifier(_student(prompted: false));
        final service = _FirestoreLikeUserService(profile);
        await _pumpApp(
          tester,
          profile: profile,
          userService: service,
          placementService: build(),
        );

        await _choose(tester, 'Mulai Tes', service);

        expect(find.byType(PlacementTestScreen), findsOneWidget);
        expect(find.text(title), findsOneWidget);
        expect(find.text(body), findsOneWidget);
        expect(find.byType(DashboardScreen), findsNothing);
      });
    });

    testWidgets('still opens the test when marking the offer fails', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        profile: ValueNotifier(_student(prompted: false)),
        userService: _RefusingUserService(),
      );

      await tester.tap(find.text('Mulai Tes'));
      await tester.pumpAndSettle();

      expect(find.byType(PlacementTestScreen), findsOneWidget);
    });
  });

  group('"Nanti Saja"', () {
    testWidgets('goes to the dashboard, and the offer is marked as seen', (
      tester,
    ) async {
      final profile = ValueNotifier(_student(prompted: false));
      final service = _FirestoreLikeUserService(profile);
      await _pumpApp(tester, profile: profile, userService: service);

      await _choose(tester, 'Nanti Saja', service);

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(PlacementTestScreen), findsNothing);
      expect(find.byType(PlacementTestOfferScreen), findsNothing);
      expect(service.promptedUids, ['student-1']);
    });
  });
}
