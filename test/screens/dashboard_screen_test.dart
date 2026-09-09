import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/app_user.dart';
import 'package:vocably/models/target_word_set.dart';
import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/models/vocab_word.dart';
import 'package:vocably/providers/dashboard_providers.dart';
import 'package:vocably/providers/vocab_bundle_providers.dart';
import 'package:vocably/screens/student/dashboard/dashboard_screen.dart';
import 'package:vocably/screens/student/dashboard/target_word_list_screen.dart';
import 'package:vocably/screens/student/placement_test/placement_test_placeholder_screen.dart';
import 'package:vocably/screens/student/research_assessment/research_assessment_placeholder_screen.dart';
import 'package:vocably/screens/student/vocab_browser/vocab_browser_screen.dart';
import 'package:vocably/services/target_word_set_service.dart';
import 'package:vocably/services/vocab_bundle_service.dart';
import 'package:vocably/utils/role.dart';

class _FakeTargetWordSetService extends TargetWordSetService {
  List<TargetWordSet> sets = [];

  @override
  Future<List<TargetWordSet>> fetchActiveForStudent(String studentId) async =>
      sets;
}

/// Also stands in for `VocabBrowserScreen`'s own bundle loading once a
/// Level pill navigates there — returning an empty level for anything not
/// explicitly stocked keeps that screen from ever touching real assets.
class _FakeVocabBundleService extends VocabBundleService {
  Map<String, List<VocabBundleEntry>> byLevel = {};

  @override
  Future<List<VocabBundleEntry>> loadLevelWithDelta({
    required String cefrLevel,
    required DateTime bundleGeneratedAt,
  }) async {
    return byLevel[cefrLevel] ?? const [];
  }
}

final _studentProfile = AppUser(
  uid: 'student-1',
  email: 'siswa@example.com',
  name: 'Siswa Uji',
  role: Role.siswa,
  createdAt: DateTime(2026, 1, 1),
  cefrLevel: null,
  placementTestCompleted: false,
  placementTestPrompted: true,
);

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required AppUser profile,
  _FakeTargetWordSetService? targetWordSetService,
  _FakeVocabBundleService? vocabBundleService,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        targetWordSetServiceProvider.overrideWithValue(
          targetWordSetService ?? _FakeTargetWordSetService(),
        ),
        vocabBundleServiceProvider.overrideWithValue(
          vocabBundleService ?? _FakeVocabBundleService(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Harness')),
          body: DashboardScreen(profile: profile),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DashboardScreen — Target Kata Hari Ini card', () {
    testWidgets('shows the empty state when there is no active target set', (
      tester,
    ) async {
      await _pumpDashboard(tester, profile: _studentProfile);

      expect(find.text('Belum ada target kata dari guru'), findsOneWidget);
    });

    testWidgets('shows the word count when target sets resolve to entries', (
      tester,
    ) async {
      final targetWordSetService = _FakeTargetWordSetService()
        ..sets = [
          TargetWordSet(
            id: 'set-1',
            teacherId: 'teacher-1',
            wordIds: const ['run', 'souvenir'],
            cefrLevel: 'A1',
            startAt: DateTime(2020, 1, 1),
            endAt: DateTime(2099, 12, 31),
            targetStudentIds: const ['__all__'],
            createdAt: DateTime(2020, 1, 1),
          ),
        ];
      final bundleService = _FakeVocabBundleService()
        ..byLevel = {
          'A1': [
            VocabBundleEntry(
              word: 'run',
              meanings: const [VocabMeaning(pos: 'verb', translation: 'lari')],
              cefrLevel: 'A1',
              topics: const [],
            ),
            VocabBundleEntry(
              word: 'souvenir',
              meanings: const [
                VocabMeaning(pos: 'noun', translation: 'oleh-oleh'),
              ],
              cefrLevel: 'A1',
              topics: const [],
            ),
          ],
        };

      await _pumpDashboard(
        tester,
        profile: _studentProfile,
        targetWordSetService: targetWordSetService,
        vocabBundleService: bundleService,
      );

      expect(find.text('2 kata dari Guru'), findsOneWidget);
    });

    testWidgets('tapping the card opens TargetWordListScreen', (tester) async {
      await _pumpDashboard(tester, profile: _studentProfile);

      await tester.tap(find.text('Target Kata Hari Ini'));
      await tester.pumpAndSettle();

      expect(find.byType(TargetWordListScreen), findsOneWidget);
    });

    testWidgets(
      'Milestone 7: the list\'s CTA starts the flow (sourceType targetGuru) and opens Fase 1',
      (tester) async {
        final targetWordSetService = _FakeTargetWordSetService()
          ..sets = [
            TargetWordSet(
              id: 'set-1',
              teacherId: 'teacher-1',
              wordIds: const ['run'],
              cefrLevel: 'A1',
              startAt: DateTime(2020, 1, 1),
              endAt: DateTime(2099, 12, 31),
              targetStudentIds: const ['__all__'],
              createdAt: DateTime(2020, 1, 1),
            ),
          ];
        final bundleService = _FakeVocabBundleService()
          ..byLevel = {
            'A1': [
              VocabBundleEntry(
                word: 'run',
                meanings: const [
                  VocabMeaning(pos: 'verb', translation: 'lari'),
                ],
                cefrLevel: 'A1',
                topics: const [],
              ),
            ],
          };

        await _pumpDashboard(
          tester,
          profile: _studentProfile,
          targetWordSetService: targetWordSetService,
          vocabBundleService: bundleService,
        );

        await tester.tap(find.text('Target Kata Hari Ini'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('📖 Belajar Kata Ini dengan Cerita'));
        await tester.pumpAndSettle();

        expect(find.text('Baca Cerita'), findsOneWidget);
      },
    );
  });

  group('DashboardScreen — Level card', () {
    testWidgets(
      'cefrLevel == null shows no active-level ring and the placement-test prompt',
      (tester) async {
        await _pumpDashboard(tester, profile: _studentProfile);

        expect(
          find.text('Kamu belum mengambil tes penempatan.'),
          findsOneWidget,
        );
        expect(find.text('Ambil Placement Test'), findsOneWidget);
        for (final level in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']) {
          expect(find.text(level), findsOneWidget);
        }
      },
    );

    testWidgets(
      'cefrLevel set shows the current level and the retake wording',
      (tester) async {
        final profile = AppUser(
          uid: 'student-1',
          email: 'siswa@example.com',
          name: 'Siswa Uji',
          role: Role.siswa,
          createdAt: DateTime(2026, 1, 1),
          cefrLevel: 'B1',
          placementTestCompleted: true,
          placementTestPrompted: true,
        );

        await _pumpDashboard(tester, profile: profile);

        expect(find.text('Level kamu saat ini: B1'), findsOneWidget);
        expect(find.text('Ambil Ulang Placement Test'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a level pill seeds the browse filter and opens VocabBrowserScreen',
      (tester) async {
        await _pumpDashboard(tester, profile: _studentProfile);

        await tester.tap(find.text('B1'));
        await tester.pumpAndSettle();

        expect(find.byType(VocabBrowserScreen), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the placement-test link opens the placeholder screen',
      (tester) async {
        await _pumpDashboard(tester, profile: _studentProfile);

        await tester.tap(find.text('Ambil Placement Test'));
        await tester.pumpAndSettle();

        expect(find.byType(PlacementTestPlaceholderScreen), findsOneWidget);
      },
    );
  });

  group('DashboardScreen — Pre-Test/Post-Test section', () {
    testWidgets('shows both entry points with a "Segera" badge', (
      tester,
    ) async {
      await _pumpDashboard(tester, profile: _studentProfile);

      expect(find.text('Pre-Test'), findsOneWidget);
      expect(find.text('Post-Test'), findsOneWidget);
      expect(find.text('Segera'), findsNWidgets(2));
    });

    testWidgets(
      'tapping Pre-Test opens the research-assessment placeholder screen',
      (tester) async {
        await _pumpDashboard(tester, profile: _studentProfile);

        await tester.tap(find.text('Pre-Test'));
        await tester.pumpAndSettle();

        expect(
          find.byType(ResearchAssessmentPlaceholderScreen),
          findsOneWidget,
        );
        expect(find.text('Pre-Test akan segera hadir'), findsOneWidget);
      },
    );
  });

  group('DashboardScreen — no duplicate logout', () {
    testWidgets(
      'does not render a standalone Keluar button in the dashboard body',
      (tester) async {
        await _pumpDashboard(tester, profile: _studentProfile);

        expect(find.text('Keluar'), findsNothing);
      },
    );
  });
}
