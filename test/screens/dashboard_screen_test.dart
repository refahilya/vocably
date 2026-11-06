import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/app_user.dart';
import 'package:vocably/models/learning_session.dart';
import 'package:vocably/models/research_treatment.dart';
import 'package:vocably/providers/learning_session_controller.dart';
import 'package:vocably/providers/research_treatment_providers.dart';
import 'package:vocably/services/research_treatment_service.dart';
import 'package:vocably/models/target_word_set.dart';
import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/models/vocab_word.dart';
import 'package:vocably/providers/dashboard_providers.dart';
import 'package:vocably/providers/vocab_bundle_providers.dart';
import 'package:vocably/screens/student/dashboard/dashboard_screen.dart';
import 'package:vocably/screens/student/dashboard/target_word_list_screen.dart';
import 'package:vocably/providers/placement_test_providers.dart';
import 'package:vocably/screens/student/placement_test/placement_test_screen.dart';
import 'package:vocably/models/research_attempt.dart';
import 'package:vocably/providers/research_assessment_providers.dart';
import 'package:vocably/screens/student/research_assessment/research_assessment_screen.dart';
import 'package:vocably/services/research_assessment_service.dart';
import 'package:vocably/screens/student/vocab_browser/vocab_browser_screen.dart';
import 'package:vocably/services/target_word_set_service.dart';
import 'package:vocably/screens/student/vocab_browser/learning_cart_screen.dart';
import 'package:vocably/screens/student/vocab_browser/word_detail_screen.dart';
import 'package:vocably/services/vocab_bundle_service.dart';
import 'package:vocably/utils/cefr_levels.dart';
import 'package:vocably/utils/role.dart';
import 'package:vocably/utils/vocab_browse_filter.dart';
import 'package:vocably/widgets/cefr_level_selector.dart';

import '../support/fake_placement_service.dart';
import '../support/fake_research_assessment_service.dart';

class _FakeTargetWordSetService extends TargetWordSetService {
  List<TargetWordSet> sets = [];

  @override
  Future<List<TargetWordSet>> fetchActiveForStudent(String studentId) async =>
      sets;

  @override
  Stream<List<TargetWordSet>> watchActiveForStudent(String studentId) =>
      Stream.fromFuture(fetchActiveForStudent(studentId));
}

/// The student's research treatment record; not a participant by default,
/// so the background reconciliation does nothing.
class _FakeTreatmentService extends ResearchTreatmentService {
  TreatmentRecord record = TreatmentRecord.empty;

  @override
  Future<bool> isParticipant(String uid) async => false;

  @override
  Future<TreatmentRecord> fetchRecord(String uid) async => record;
}

/// Also stands in for `VocabBrowserScreen`'s own bundle loading once a
/// Level pill navigates there — returning an empty level for anything not
/// explicitly stocked keeps that screen from ever touching real assets.
class _FakeVocabBundleService extends VocabBundleService {
  Map<String, List<VocabBundleEntry>> byLevel = {};
  final loadedLevels = <String>[];

  @override
  Future<List<VocabBundleEntry>> loadLevelWithDelta({
    required String cefrLevel,
    required DateTime bundleGeneratedAt,
  }) async {
    loadedLevels.add(cefrLevel);
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
  FakeResearchAssessmentService? researchService,
  _FakeTreatmentService? treatmentService,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      // No automatic retry, so a simulated read failure stays visible.
      retry: (_, _) => null,
      overrides: [
        researchAssessmentServiceProvider.overrideWithValue(
          researchService ?? FakeResearchAssessmentService(),
        ),
        placementServiceProvider.overrideWithValue(FakePlacementService()),
        researchTreatmentServiceProvider.overrideWithValue(treatmentService ?? _FakeTreatmentService()),
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
      'no resultLevel shows no active-level ring and the placement-test prompt',
      (tester) async {
        await _pumpDashboard(tester, profile: _studentProfile);

        expect(
          find.text('Kamu belum mengambil tes penempatan.'),
          findsOneWidget,
        );
        expect(find.text('Ambil Tes Penempatan'), findsOneWidget);
        for (final level in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']) {
          expect(find.text(level), findsOneWidget);
        }
      },
    );

    testWidgets(
      'resultLevel shows the active level; the legacy cefrLevel is ignored',
      (tester) async {
        final profile = AppUser(
          uid: 'student-1',
          email: 'siswa@example.com',
          name: 'Siswa Uji',
          role: Role.siswa,
          createdAt: DateTime(2026, 1, 1),
          cefrLevel: 'C1',
          resultLevel: 'B1',
          placementTestCompleted: true,
          placementTestPrompted: true,
        );

        await _pumpDashboard(tester, profile: profile);

        expect(find.text('Level kamu saat ini: B1'), findsOneWidget);
        expect(find.text('Lihat Tes Penempatan'), findsOneWidget);
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
      'tapping the placement-test link opens the Placement Test',
      (tester) async {
        await _pumpDashboard(tester, profile: _studentProfile);

        await tester.tap(find.text('Ambil Tes Penempatan'));
        await tester.pumpAndSettle();

        expect(find.byType(PlacementTestScreen), findsOneWidget);
        expect(find.text('Tes Penempatan Kosakata'), findsOneWidget);
      },
    );
  });

  group('DashboardScreen — the level ladder opens that level', () {
    /// One word per level (C2 stays empty, as in the real bundle), plus
    /// enough A2 words for a second page.
    _FakeVocabBundleService stockedBundle() {
      VocabBundleEntry entry(String word, String level) => VocabBundleEntry(
        word: word,
        meanings: const [VocabMeaning(pos: 'noun', translation: 'arti')],
        cefrLevel: level,
        topics: const ['Topik'],
      );
      return _FakeVocabBundleService()
        ..byLevel = {
          for (final level in kCefrLevels.where((l) => l != 'C2'))
            level: [entry('kata$level', level)],
          'A2': [for (var i = 0; i < 75; i++) entry('kataA2n$i', 'A2')],
        };
    }

    Finder ladder(String level) => find.descendant(
      of: find.byType(DashboardScreen),
      matching: find.text(level),
    );

    String browserLevel(WidgetTester tester) =>
        tester.widget<CefrLevelSelector>(find.byType(CefrLevelSelector)).selected;

    Set<VocabBrowseMode> browserMode(WidgetTester tester) => tester
        .widget<SegmentedButton<VocabBrowseMode>>(
          find.byType(SegmentedButton<VocabBrowseMode>),
        )
        .selected;

    for (final level in kCefrLevels) {
      testWidgets('tapping $level opens the browser at $level', (tester) async {
        final bundle = stockedBundle();
        await _pumpDashboard(
          tester,
          profile: _studentProfile,
          vocabBundleService: bundle,
        );
        bundle.loadedLevels.clear();

        await tester.tap(ladder(level));
        await tester.pumpAndSettle();

        expect(browserLevel(tester), level);
        expect(
          bundle.loadedLevels,
          [level],
          reason: 'no other level is fetched on the way there',
        );
        if (level == 'C2') {
          expect(find.text('Belum ada kata di level ini.'), findsOneWidget);
        } else if (level == 'A2') {
          expect(find.text('kataA2n0'), findsOneWidget);
        } else {
          expect(find.text('kata$level'), findsOneWidget);
        }
      });
    }

    testWidgets('a level opened after leaving another starts clean', (
      tester,
    ) async {
      await _pumpDashboard(
        tester,
        profile: _studentProfile,
        vocabBundleService: stockedBundle(),
      );

      await tester.tap(ladder('B1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('POS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C1'));
      await tester.pumpAndSettle();
      expect(browserLevel(tester), 'C1');

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(ladder('A2'));
      await tester.pumpAndSettle();

      expect(browserLevel(tester), 'A2');
      expect(browserMode(tester), {VocabBrowseMode.alphabetical});
      expect(find.text('Halaman 1 dari 2'), findsOneWidget);
    });

    testWidgets('the same level reopened starts clean', (tester) async {
      await _pumpDashboard(
        tester,
        profile: _studentProfile,
        vocabBundleService: stockedBundle(),
      );

      await tester.tap(ladder('A2'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('vocabBrowserNextPage')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tema'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(ladder('A2'));
      await tester.pumpAndSettle();

      expect(browserLevel(tester), 'A2');
      expect(browserMode(tester), {VocabBrowseMode.alphabetical});
      expect(find.text('Halaman 1 dari 2'), findsOneWidget);
    });

    testWidgets('reopening during the closing animation inherits nothing', (
      tester,
    ) async {
      await _pumpDashboard(
        tester,
        profile: _studentProfile,
        vocabBundleService: stockedBundle(),
      );

      await tester.tap(ladder('B1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('POS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C1'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.byType(VocabBrowserScreen),
        findsOneWidget,
        reason: 'the old route must still be on its way out',
      );
      await tester.tap(ladder('B1'));
      await tester.pumpAndSettle();

      expect(browserLevel(tester), 'B1');
      expect(browserMode(tester), {VocabBrowseMode.alphabetical});
    });

    testWidgets('trips to the cart and a word keep the level and page', (
      tester,
    ) async {
      await _pumpDashboard(
        tester,
        profile: _studentProfile,
        vocabBundleService: stockedBundle(),
      );

      await tester.tap(ladder('A2'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('vocabBrowserNextPage')));
      await tester.pumpAndSettle();
      expect(find.text('Halaman 2 dari 2'), findsOneWidget);

      await tester.tap(find.text('Keranjang Pelajari kosong'));
      await tester.pumpAndSettle();
      expect(find.byType(LearningCartScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(browserLevel(tester), 'A2');
      expect(find.text('Halaman 2 dari 2'), findsOneWidget);

      await tester.tap(find.textContaining('kataA2n').first);
      await tester.pumpAndSettle();
      expect(find.byType(WordDetailScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(browserLevel(tester), 'A2');
      expect(find.text('Halaman 2 dari 2'), findsOneWidget);
    });
  });

  group('DashboardScreen — Pre-Test/Post-Test section', () {
    ResearchAttemptRecord attempt(
      ResearchStage stage,
      ResearchAttemptStatus status,
    ) => ResearchAttemptRecord(
      attemptId: ResearchAttemptRecord.idFor('student-1', stage, 1),
      studentId: 'student-1',
      stage: stage,
      attemptNumber: 1,
      band: 'A2',
      instrumentVersion: 'v1',
      itemOrder: const [],
      optionOrder: const {},
      responses: const {},
      status: status,
    );

    testWidgets('a student who is not a participant sees "Belum tersedia"', (
      tester,
    ) async {
      await _pumpDashboard(tester, profile: _studentProfile);

      expect(find.text('Pre-Test'), findsOneWidget);
      expect(find.text('Post-Test'), findsOneWidget);
      expect(find.text('Belum tersedia'), findsNWidgets(2));
      expect(find.text('Segera'), findsNothing);
    });

    testWidgets('shows the persisted status of each stage', (tester) async {
      final service = FakeResearchAssessmentService(
        participant: participantFor(preTest: 1),
      );
      await _pumpDashboard(
        tester,
        profile: _studentProfile,
        researchService: service,
      );
      expect(find.text('Siap dikerjakan'), findsOneWidget);
      expect(find.text('Belum dibuka'), findsOneWidget);
    });

    testWidgets('in progress, completed and an opened posttest', (
      tester,
    ) async {
      final inProgress =
          FakeResearchAssessmentService(participant: participantFor(preTest: 1))
            ..putAttempt(
              attempt(ResearchStage.preTest, ResearchAttemptStatus.inProgress),
            );
      await _pumpDashboard(
        tester,
        profile: _studentProfile,
        researchService: inProgress,
      );
      expect(find.text('Lanjutkan'), findsOneWidget);

      final done =
          FakeResearchAssessmentService(
            participant: participantFor(preTest: 1, postTest: 1),
          )..putAttempt(
            attempt(ResearchStage.preTest, ResearchAttemptStatus.completed),
          );
      await _pumpDashboard(
        tester,
        profile: _studentProfile,
        researchService: done,
      );
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.text('Siap dikerjakan'), findsOneWidget);
    });

    testWidgets('a failed read shows "Gagal memuat", not a placeholder', (
      tester,
    ) async {
      final service = FakeResearchAssessmentService()
        ..readFaults.addAll([
          ResearchFailureKind.unavailable,
          ResearchFailureKind.unavailable,
        ]);
      await _pumpDashboard(
        tester,
        profile: _studentProfile,
        researchService: service,
      );
      expect(find.text('Gagal memuat'), findsNWidgets(2));
    });

    testWidgets('tapping Pre-Test opens the assessment screen', (tester) async {
      await _pumpDashboard(tester, profile: _studentProfile);

      await tester.tap(find.text('Pre-Test'));
      await tester.pumpAndSettle();

      expect(find.byType(ResearchAssessmentScreen), findsOneWidget);
      expect(find.text('Belum terdaftar'), findsOneWidget);
    });
  });

  group('DashboardScreen — layout', () {
    testWidgets('the level ladder rises and marks the active level', (tester) async {
      await _pumpDashboard(
        tester,
        profile: AppUser(
          uid: 'student-1',
          email: 'siswa@example.com',
          name: 'Siswa Uji',
          role: Role.siswa,
          createdAt: DateTime(2026, 1, 1),
          resultLevel: 'B1',
          placementTestCompleted: true,
          placementTestPrompted: true,
        ),
      );
      expect(find.text('Level kamu saat ini: B1'), findsOneWidget);
      final a1 = tester.getBottomLeft(find.text('A1'));
      final c1 = tester.getBottomLeft(find.text('C1'));
      expect(c1.dy, a1.dy, reason: 'rungs stand on one baseline');
      expect(
        tester.getSemantics(find.bySemanticsLabel('B1')),
        matchesSemantics(
          label: 'B1',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('the two main panels stack on phones and sit side by side on tablets', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpDashboard(tester, profile: _studentProfile);
      final phoneTarget = tester.getTopLeft(find.text('Target Kata Hari Ini'));
      final phoneLevel = tester.getTopLeft(find.text('Level'));
      expect(phoneLevel.dy, greaterThan(phoneTarget.dy));

      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpAndSettle();
      final wideTarget = tester.getTopLeft(find.text('Target Kata Hari Ini'));
      final wideLevel = tester.getTopLeft(find.text('Level'));
      expect(wideLevel.dx, greaterThan(wideTarget.dx));
    });
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

  group('DashboardScreen — research treatment session (DATA_MODEL.md §6e)', () {
    VocabBundleEntry entry(String w) => VocabBundleEntry(
      word: w,
      meanings: const [VocabMeaning(pos: 'noun', translation: 'arti')],
      cefrLevel: 'B1',
      topics: const [],
    );
    final words = ['wa', 'wb', 'wc', 'wd', 'we'];

    TargetWordSet researchSet({List<String> students = const ['student-1']}) => TargetWordSet(
      id: 'rt_t1_B1_s2_o1',
      teacherId: 'researcher-1',
      wordIds: words,
      cefrLevel: 'B1',
      startAt: DateTime.now().subtract(const Duration(minutes: 5)),
      endAt: DateTime.now().add(const Duration(minutes: 55)),
      targetStudentIds: students,
      createdAt: DateTime.now(),
      research: const TreatmentSetInfo(
        planVersion: 't1',
        instrumentVersion: 'v1',
        band: 'B1',
        session: 2,
        kind: TreatmentSetKind.regular,
        opening: 1,
      ),
    );

    TargetWordSet ordinarySet() => TargetWordSet(
      id: 'set-1',
      teacherId: 'teacher-1',
      wordIds: const ['wz'],
      cefrLevel: 'B1',
      startAt: DateTime(2020),
      endAt: DateTime(2099, 12, 31),
      targetStudentIds: const ['__all__'],
      createdAt: DateTime(2020),
    );

    _FakeVocabBundleService bundle() => _FakeVocabBundleService()..byLevel = {'B1': [for (final w in [...words, 'wz']) entry(w)]};

    testWidgets('an open session for this student shows its own card; its words never join Target Kata', (tester) async {
      await _pumpDashboard(
        tester,
        profile: _studentProfile,
        targetWordSetService: _FakeTargetWordSetService()..sets = [researchSet(), ordinarySet()],
        vocabBundleService: bundle(),
      );
      expect(find.text('Sesi Riset ke-2'), findsOneWidget);
      expect(find.textContaining('5 kata, dibuka sampai pukul'), findsOneWidget);
      expect(find.text('1 kata dari Guru'), findsOneWidget, reason: 'the research words are not merged');
    });

    testWidgets('the card opens the session list, whose CTA starts the flow with the session reference', (tester) async {
      await _pumpDashboard(
        tester,
        profile: _studentProfile,
        targetWordSetService: _FakeTargetWordSetService()..sets = [researchSet()],
        vocabBundleService: bundle(),
      );
      await tester.tap(find.text('Sesi Riset ke-2'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Sesi Riset ke-2'), findsOneWidget);
      final container = ProviderScope.containerOf(tester.element(find.byType(TargetWordListScreen)));
      await tester.tap(find.text('📖 Belajar Kata Ini dengan Cerita'));
      await tester.pump();
      final flow = container.read(learningFlowControllerProvider);
      expect(flow.wordIds, words);
      expect(flow.sourceType, LearningSessionSourceType.targetGuru);
      expect([flow.research?.setId, flow.research?.session], ['rt_t1_B1_s2_o1', 2]);
    });

    testWidgets('a recorded session says so and cannot be started again', (tester) async {
      await _pumpDashboard(
        tester,
        profile: _studentProfile,
        targetWordSetService: _FakeTargetWordSetService()..sets = [researchSet()],
        vocabBundleService: bundle(),
        treatmentService: _FakeTreatmentService()
          ..record = const TreatmentRecord(
            uid: 'student-1',
            sessions: {2: TreatmentRecordEntry(sessionId: 'ls', setId: 'rt_t1_B1_s2_o1', kind: TreatmentSetKind.regular)},
          ),
      );
      expect(find.text('Sudah selesai'), findsOneWidget);
      await tester.tap(find.text('Sesi Riset ke-2'));
      await tester.pumpAndSettle();
      expect(find.text('Sesi riset ini sudah selesai.'), findsOneWidget);
      expect(find.text('📖 Belajar Kata Ini dengan Cerita'), findsNothing);
    });

    testWidgets('no card for a student the researcher did not mark present', (tester) async {
      await _pumpDashboard(
        tester,
        profile: _studentProfile,
        targetWordSetService: _FakeTargetWordSetService()..sets = [researchSet(students: const ['someone-else'])],
        vocabBundleService: bundle(),
      );
      expect(find.textContaining('Sesi Riset'), findsNothing);
    });
  });
}
