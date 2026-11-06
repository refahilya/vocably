import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vocably/models/app_user.dart';
import 'package:vocably/models/learning_progress.dart';
import 'package:vocably/models/learning_session.dart';
import 'package:vocably/models/placement_instrument.dart';
import 'package:vocably/models/research_panel.dart';
import 'package:vocably/models/research_participant.dart';
import 'package:vocably/models/research_attempt.dart';
import 'package:vocably/models/research_instrument.dart';
import 'package:vocably/models/target_word_set.dart';
import 'package:vocably/models/topic.dart';
import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/models/vocab_word.dart';
import 'package:vocably/providers/ai_worker_providers.dart';
import 'package:vocably/providers/dashboard_providers.dart';
import 'package:vocably/providers/dictionary_providers.dart';
import 'package:vocably/providers/history_providers.dart';
import 'package:vocably/providers/learning_cart_providers.dart';
import 'package:vocably/providers/learning_session_controller.dart';
import 'package:vocably/providers/placement_test_providers.dart';
import 'package:vocably/providers/research_assessment_providers.dart';
import 'package:vocably/providers/research_panel_providers.dart';
import 'package:vocably/providers/research_treatment_providers.dart';
import 'package:vocably/services/research_treatment_service.dart';
import 'package:vocably/providers/vocab_bundle_providers.dart';
import 'package:vocably/providers/vocab_management_providers.dart';
import 'package:vocably/screens/auth/complete_registration_screen.dart';
import 'package:vocably/screens/auth/login_screen.dart';
import 'package:vocably/screens/auth/sign_up_screen.dart';
import 'package:vocably/screens/student/dashboard/dashboard_screen.dart';
import 'package:vocably/screens/student/dashboard/target_word_list_screen.dart';
import 'package:vocably/screens/student/history/history_screen.dart';
import 'package:vocably/screens/student/history/session_detail_screen.dart';
import 'package:vocably/screens/student/learning_flow/cloze_test_screen.dart';
import 'package:vocably/screens/student/learning_flow/cowrite_screen.dart';
import 'package:vocably/screens/student/learning_flow/story_reading_screen.dart';
import 'package:vocably/screens/student/placement_test/placement_test_offer_screen.dart';
import 'package:vocably/screens/student/placement_test/placement_test_screen.dart';
import 'package:vocably/screens/student/research_assessment/research_assessment_screen.dart';
import 'package:vocably/screens/student/vocab_browser/learning_cart_screen.dart';
import 'package:vocably/screens/student/vocab_browser/vocab_browser_screen.dart';
import 'package:vocably/screens/student/vocab_browser/word_detail_screen.dart';
import 'package:vocably/screens/teacher/research_panel/research_panel_screen.dart';
import 'package:vocably/screens/teacher/target_words/set_target_word_screen.dart';
import 'package:vocably/screens/teacher/target_words/target_words_screen.dart';
import 'package:vocably/screens/teacher/vocab_management/edit_kata_screen.dart';
import 'package:vocably/screens/teacher/vocab_management/vocab_management_screen.dart';
import 'package:vocably/services/ai_worker_service.dart';
import 'package:vocably/services/dictionary_api_service.dart';
import 'package:vocably/services/learning_progress_service.dart';
import 'package:vocably/services/learning_session_service.dart';
import 'package:vocably/services/target_word_set_service.dart';
import 'package:vocably/services/topics_service.dart';
import 'package:vocably/services/vocab_bundle_service.dart';
import 'package:vocably/services/vocab_word_service.dart';
import 'package:vocably/theme/theme.dart';
import 'package:vocably/utils/role.dart';
import 'package:vocably/widgets/app_nav_shell.dart';
import 'package:vocably/widgets/stepper_header.dart';
import 'package:vocably/models/research_treatment.dart';

import '../support/app_fonts.dart';
import '../support/fake_placement_service.dart';
import '../support/fake_research_assessment_service.dart';
import '../support/fake_research_panel_service.dart';

/// Every screen, at every required viewport, with the real fonts and the
/// longest content the app can meet. A RenderFlex overflow or an unbounded
/// layout fails the test by itself: Flutter reports both as errors.
const _viewports = [
  Size(320, 640),
  Size(390, 844),
  Size(430, 932),
  Size(768, 1024),
  Size(1024, 768),
  Size(1280, 800),
  Size(1440, 900),
  Size(1920, 1080),
];

const _longWord = 'internationalization';
const _phrase = 'take something into consideration';
const _longTranslation =
    'mempertimbangkan sesuatu dengan sangat hati-hati sebelum mengambil keputusan';

VocabBundleEntry _entry(String word, {String level = 'B1'}) => VocabBundleEntry(
  word: word,
  meanings: const [
    VocabMeaning(pos: 'noun', translation: _longTranslation),
    VocabMeaning(pos: 'verb', translation: 'bentuk kata kerja'),
  ],
  cefrLevel: level,
  topics: const ['Perjalanan dan Pariwisata', 'General'],
);

final _words = [_entry(_longWord), _entry(_phrase), _entry('run'), _entry('souvenir')];

final _student = AppUser(
  uid: 'student-1',
  email: 'siswa@example.test',
  name: 'Muhammad Rizky Pratama Wijaya Kusumaningrat',
  role: Role.siswa,
  createdAt: DateTime(2026, 1, 1),
  resultLevel: 'B1',
  placementTestCompleted: true,
  placementTestPrompted: true,
);

final _teacher = AppUser(
  uid: 'teacher-1',
  email: 'guru@example.test',
  name: 'Ibu Guru',
  role: Role.guru,
  createdAt: DateTime(2026, 1, 1),
);

class _Bundle extends VocabBundleService {
  @override
  Future<List<VocabBundleEntry>> loadLevelWithDelta({
    required String cefrLevel,
    required DateTime bundleGeneratedAt,
  }) async => _words;
}

class _Sets extends TargetWordSetService {
  final _set = TargetWordSet(
    id: 'set-1',
    teacherId: 'teacher-1',
    wordIds: [_longWord, _phrase, 'run', 'souvenir'],
    cefrLevel: 'B1',
    startAt: DateTime(2020, 1, 1),
    endAt: DateTime(2099, 12, 31),
    targetStudentIds: const ['__all__'],
    createdAt: DateTime(2020, 1, 1),
  );

  /// An official research session open for the student (`DATA_MODEL.md` §6e).
  static final research = TargetWordSet(
    id: 'rt_t1_B1_s3_o1',
    teacherId: 'teacher-1',
    wordIds: [_longWord, _phrase, 'run', 'souvenir'],
    cefrLevel: 'B1',
    startAt: DateTime.now().subtract(const Duration(minutes: 5)),
    endAt: DateTime.now().add(const Duration(minutes: 85)),
    targetStudentIds: const ['student-1'],
    createdAt: DateTime.now(),
    research: const TreatmentSetInfo(
      planVersion: 't1',
      instrumentVersion: 'v1',
      band: 'B1',
      session: 3,
      kind: TreatmentSetKind.regular,
      opening: 1,
    ),
  );

  @override
  Future<List<TargetWordSet>> fetchActiveForStudent(String studentId) async => [_set, research];

  @override
  Stream<List<TargetWordSet>> watchActiveForStudent(String studentId) =>
      Stream.fromFuture(fetchActiveForStudent(studentId));

  @override
  Future<List<TargetWordSet>> fetchForTeacher(String teacherId) async => [_set, _set, _set, research];
}

class _Treatment extends ResearchTreatmentService {
  @override
  Future<bool> isParticipant(String uid) async => false;

  @override
  Future<TreatmentRecord> fetchRecord(String uid) async => TreatmentRecord.empty;
}

class _Topics extends TopicsService {
  @override
  Future<List<Topic>> fetchAll() async => [
    for (final name in ['General', 'Perjalanan dan Pariwisata', 'Makanan', 'Pekerjaan'])
      Topic(name: name, createdBy: 'csvImport', createdAt: DateTime(2026, 1, 1)),
  ];
}

class _Words extends VocabWordService {
  @override
  Future<VocabWord?> findByWord(String normalizedWord) async => null;
}

final _session = LearningSession(
  id: 'session-1',
  studentId: 'student-1',
  sourceType: LearningSessionSourceType.targetGuru,
  wordIds: [_longWord, _phrase, 'run'],
  storyTitle: 'Liburan panjang yang tidak pernah terlupakan oleh seluruh keluarga',
  storyContent:
      'She [[$_longWord|$_longWord]] again and [[run|ran]] home. ${'The long story continues. ' * 12}',
  storyTranslation: 'Terjemahan cerita. ' * 12,
  currentPhase: LearningSessionPhase.selesai,
  clozeTestResult: const {},
  cowriteTranscript: const [],
  cowriteWordsUsedCorrectly: const [],
  startedAt: DateTime(2026, 11, 2, 9, 30),
  completedAt: DateTime(2026, 11, 2, 10),
);

class _Sessions extends LearningSessionService {
  @override
  Future<List<LearningSession>> fetchForStudent(String studentId) async => [_session, _session];

  @override
  Future<String> createSession({
    required String studentId,
    required List<String> wordIds,
    required String sourceType,
    required String storyTitle,
    required String storyContent,
    required String? storyTranslation,
    ResearchSessionRef? research,
  }) async => 'session-1';

  @override
  Future<void> advanceToClozeTest(String sessionId) async {}
}

class _Progress extends LearningProgressService {
  @override
  Future<List<LearningProgress>> fetchForStudent(String studentId) async => [
    for (final (word, mastery) in [
      (_longWord, MasteryStatus.difficult),
      (_phrase, MasteryStatus.difficult),
      ('run', MasteryStatus.mastered),
    ])
      LearningProgress(
        studentId: studentId,
        wordId: word,
        learnedStatus: 'sudah_dipelajari',
        masteryStatus: mastery,
        firstLearnedAt: DateTime(2026, 11, 1),
        lastUpdatedAt: DateTime(2026, 11, 2),
        lastSessionId: 'session-1',
      ),
  ];
}

class _Ai extends AiWorkerService {
  @override
  Future<GenerateStoryResult> generateStory({
    required List<String> targetWords,
    required String prompt,
  }) async => GenerateStoryResult(
    story:
        '${'The morning was quiet and everyone was happy to go. ' * 3}'
        'They talked about [[$_phrase|$_phrase]] and [[run|ran]] to [[$_longWord|$_longWord]].',
    translation: 'Terjemahan cerita yang cukup panjang. ' * 6,
  );

  @override
  Future<CowriteTurnResult> cowriteTurn({
    required List<Map<String, String>> transcript,
    required List<String> remainingWords,
    required bool requestSuggestion,
    bool studentTurnContainsIndonesian = false,
  }) async => const CowriteTurnResult(
    aiTurn: 'What happens next in the story?',
    feedback: null,
    hasError: false,
    wordsUsedCorrectly: [],
    suggestion: 'Coba tulis kalimat tentang liburan keluargamu yang panjang.',
    aiUsedWords: [],
  );
}

http.Client _dictionary() => MockClient(
  (request) async => http.Response(
    jsonEncode([
      {
        'word': _longWord,
        'phonetics': [
          {'text': '/ˌɪntərˌnæʃənəlaɪˈzeɪʃən/'},
        ],
        'meanings': [
          {
            'partOfSpeech': 'noun',
            'definitions': [
              {
                'definition': 'The process of making something usable in many countries. ' * 3,
                'example': 'The long example sentence goes on for quite a while indeed.',
              },
            ],
          },
        ],
      },
    ]),
    200,
  ),
);

List<dynamic> _overrides({
  FakePlacementService? placement,
  FakeResearchAssessmentService? research,
  ResearchInstrument? instrument,
}) => [
  vocabBundleServiceProvider.overrideWithValue(_Bundle()),
  targetWordSetServiceProvider.overrideWithValue(_Sets()),
  topicsServiceProvider.overrideWithValue(_Topics()),
  vocabWordServiceProvider.overrideWithValue(_Words()),
  learningSessionServiceProvider.overrideWithValue(_Sessions()),
  learningProgressServiceProvider.overrideWithValue(_Progress()),
  aiWorkerServiceProvider.overrideWithValue(_Ai()),
  dictionaryApiServiceProvider.overrideWithValue(DictionaryApiService(client: _dictionary())),
  placementServiceProvider.overrideWithValue(placement ?? FakePlacementService()),
  researchAssessmentServiceProvider.overrideWithValue(
    research ?? FakeResearchAssessmentService(participant: participantFor()),
  ),
  researchAssessmentRandomProvider.overrideWithValue(Random(3)),
  researchPanelServiceProvider.overrideWithValue(_panel()),
  researchTreatmentServiceProvider.overrideWithValue(_Treatment()),
  if (instrument != null) researchInstrumentProvider('v1').overrideWith((ref) async => instrument),
];

/// A full class with the longest names and every cell state the panel can show.
FakeResearchPanelService _panel() => FakeResearchPanelService(
  operators: {'teacher-1'},
  study: activeStudy(open: {PanelStage.preTest}),
  participants: [
    for (var i = 0; i < 6; i++)
      panelParticipant(
        's$i',
        researchId: 'PENELITIAN-SMK-${i.toString().padLeft(3, '0')}',
        status: i == 0 ? ResearchParticipantStatus.awaitingPlacement : ResearchParticipantStatus.enrolled,
        pre: i >= 3 ? 1 : 0,
        post: i == 5 ? 1 : 0,
      ),
  ],
  roster: [
    for (var i = 0; i < 6; i++)
      PanelRosterEntry(uid: 's$i', name: 'Muhammad Rizky Ramadhan Putra Wijayakusuma $i', researchId: 'PENELITIAN-SMK-$i'),
  ],
  progress: [
    panelProgress('s0', PanelStage.placement, answered: 37),
    panelProgress('s3', PanelStage.preTest, answered: 19),
    panelProgress('s4', PanelStage.preTest, status: 'voided'),
    panelProgress('s5', PanelStage.preTest, answered: 20, status: 'completed'),
    panelProgress('s5', PanelStage.postTest, answered: 4),
    panelProgress('s6', PanelStage.preTest, answered: 20, status: 'completed'),
    panelProgress('s7', PanelStage.preTest, answered: 20, status: 'completed'),
  ],
  // Treatment: session 1 held yesterday, session 2 earlier today (closed);
  // s6 missed session 1 (make-up offered), s7 did both.
  plans: [panelPlan('B1')],
  treatmentSets: [
    panelSet('B1', 1, students: const ['s5', 's7'], startAt: DateTime.now().subtract(const Duration(hours: 27)), endAt: DateTime.now().subtract(const Duration(hours: 26))),
    panelSet('B1', 2, students: const ['s5', 's6', 's7'], startAt: DateTime.now().subtract(const Duration(hours: 3)), endAt: DateTime.now().subtract(const Duration(hours: 2))),
  ],
  records: [panelRecord('s5', {1, 2, 3, 4}), panelRecord('s6', {2}), panelRecord('s7', {1, 2})],
)..participants.addAll([
    for (final i in [6, 7])
      panelParticipant('s$i', researchId: 'PENELITIAN-SMK-00$i', pre: 1),
  ]);

void main() {
  late ResearchInstrument instrument;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
    instrument = ResearchInstrument.fromJson(
      jsonDecode(await rootBundle.loadString('assets/research/instrument_v1.json')),
      expectedVersion: 'v1',
    );
  });

  /// Pumps [home] at [size], optionally after [prepare], then [drive]s it.
  Future<void> check(
    WidgetTester tester,
    Size size,
    Widget home, {
    List<dynamic> overrides = const [],
    Future<void> Function(ProviderContainer container)? prepare,
    Future<void> Function(WidgetTester tester, ProviderContainer container)? drive,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: overrides.isEmpty ? _overrides().cast() : overrides.cast(),
    );
    addTearDown(container.dispose);
    await prepare?.call(container);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          key: UniqueKey(),
          theme: AppTheme.themeData,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await drive?.call(tester, container);
    expect(tester.takeException(), isNull);
    // Unmount inside the test so timers from the screen can't leak out.
    await tester.pumpWidget(const SizedBox.shrink());
  }

  Future<void> startFlow(ProviderContainer c, {bool toCloze = false}) async {
    final flow = c.read(learningFlowControllerProvider.notifier);
    flow.startFlow(
      studentId: 'student-1',
      wordIds: [_longWord, _phrase, 'run'],
      sourceType: LearningSessionSourceType.targetGuru,
    );
    await flow.generateStory(prompt: 'liburan');
    if (toCloze) await flow.advanceToClozeTest();
  }

  final cases = <String, Widget>{
    'login': const LoginScreen(),
    'sign up': const SignUpScreen(),
    'complete registration': const CompleteRegistrationScreen(uid: 'u', email: 'e@example.test'),
    'placement offer': PlacementTestOfferScreen(profile: _student),
    'student shell': AppNavShell(
      onLogout: () {},
      destinations: [
        AppNavDestination(label: 'Belajar', icon: Icons.school, body: DashboardScreen(profile: _student)),
        AppNavDestination(label: 'Riwayat', icon: Icons.history, body: HistoryScreen(profile: _student)),
      ],
    ),
    'teacher shell': AppNavShell(
      onLogout: () {},
      destinations: [
        AppNavDestination(label: 'Target Kata', icon: Icons.track_changes, body: TargetWordsScreen(profile: _teacher)),
        AppNavDestination(label: 'Kosakata', icon: Icons.menu_book, body: VocabManagementScreen(profile: _teacher)),
      ],
    ),
    'target word list': const TargetWordListScreen(studentId: 'student-1'),
    'research session list': TargetWordListScreen(
      studentId: 'student-1',
      research: ResearchSessionOffer(set: _Sets.research, info: _Sets.research.research!, completed: false),
    ),
    'vocabulary browser': const VocabBrowserScreen(),
    'word detail': WordDetailScreen(entry: _entry(_longWord)),
    'session detail': SessionDetailScreen(session: _session),
    'set target': SetTargetWordScreen(profile: _teacher),
    'edit word': Scaffold(body: EditKataScreen(profile: _teacher)),
    'researcher panel': AppNavShell(
      onLogout: () {},
      destinations: [
        AppNavDestination(label: 'Target Kata', icon: Icons.track_changes, body: TargetWordsScreen(profile: _teacher)),
        AppNavDestination(label: 'Kosakata', icon: Icons.menu_book, body: VocabManagementScreen(profile: _teacher)),
        AppNavDestination(label: 'Riset', icon: Icons.fact_check_outlined, body: ResearchPanelScreen(profile: _teacher)),
      ],
      initialIndex: 2,
    ),
  };

  group('renders without overflow at every viewport', () {
    for (final size in _viewports) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';
      cases.forEach((name, home) {
        testWidgets('$name @ $label', (tester) => check(tester, size, home));
      });

      testWidgets('history, both tabs @ $label', (tester) async {
        await check(
          tester,
          size,
          Scaffold(body: HistoryScreen(profile: _student)),
          drive: (tester, container) async {
            container.read(historyFilterProvider.notifier).select(HistoryMasteryFilter.difficult);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.tap(find.text('Per Sesi'));
            await tester.pumpAndSettle();
          },
        );
      });

      testWidgets('learning cart @ $label', (tester) async {
        await check(
          tester,
          size,
          const LearningCartScreen(),
          prepare: (c) async {
            for (final entry in _words) {
              c.read(learningCartProvider.notifier).toggle(entry);
            }
          },
        );
      });

      testWidgets('story, with translation @ $label', (tester) async {
        await check(
          tester,
          size,
          const StoryReadingScreen(),
          prepare: startFlow,
          drive: (tester, _) async {
            await tester.ensureVisible(find.text('Terjemahan'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Terjemahan'));
            await tester.pumpAndSettle();
          },
        );
      });

      testWidgets('cloze with a long multi-word option @ $label', (tester) async {
        await check(
          tester,
          size,
          ClozeTestScreen(random: Random(1)),
          prepare: (c) => startFlow(c, toCloze: true),
        );
      });

      testWidgets('co-write @ $label', (tester) async {
        await check(
          tester,
          size,
          const CowriteScreen(),
          prepare: (c) => startFlow(c, toCloze: true),
        );
      });

      testWidgets('placement instructions, item and summary @ $label', (tester) async {
        final placement = FakePlacementService();
        await check(
          tester,
          size,
          const PlacementTestScreen(uid: 'student-1'),
          overrides: _overrides(placement: placement),
          drive: (tester, container) async {
            final provider = placementTestControllerProvider('student-1');
            await container.read(provider.notifier).start();
            await tester.pumpAndSettle();
            expect(find.text('Soal 1 dari $kPlacementItemCount'), findsOneWidget);
            expect(tester.takeException(), isNull);
            container.read(provider.notifier).openSummary();
            await tester.pumpAndSettle();
            expect(find.text('Kirim jawaban'), findsOneWidget);
          },
        );
      });

      testWidgets('pretest instructions and item @ $label', (tester) async {
        await check(
          tester,
          size,
          const ResearchAssessmentScreen(uid: 'student-1', stage: ResearchStage.preTest),
          overrides: _overrides(
            research: FakeResearchAssessmentService(participant: participantFor()),
            instrument: instrument,
          ),
          drive: (tester, _) async {
            await tester.ensureVisible(find.text('Mulai'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Mulai'));
            await tester.pumpAndSettle();
            expect(find.text('Lanjut'), findsOneWidget);
          },
        );
      });
    }
  });

  group('treatment session dialog', () {
    for (final size in _viewports) {
      testWidgets('open session 3 @ ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        await check(
          tester,
          size,
          cases['researcher panel']!,
          drive: (tester, _) async {
            await tester.ensureVisible(find.text('Buka sesi 3'));
            await tester.tap(find.text('Buka sesi 3'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text('Buka sesi 3 band B1?'), findsOneWidget);
            expect(find.textContaining('hadir di kelas dan diawasi'), findsOneWidget);
          },
        );
      });
    }
  });

  group('large text (130%) on the smallest phone', () {
    const small = Size(320, 640);
    cases.forEach((name, home) {
      testWidgets(name, (tester) => check(tester, small, home, textScale: 1.3));
    });

    testWidgets('cloze', (tester) async {
      await check(
        tester,
        small,
        ClozeTestScreen(random: Random(1)),
        prepare: (c) => startFlow(c, toCloze: true),
        textScale: 1.3,
      );
    });

    testWidgets('story', (tester) async {
      await check(
        tester,
        small,
        const StoryReadingScreen(),
        prepare: startFlow,
        textScale: 1.3,
      );
    });

    testWidgets('co-write', (tester) async {
      await check(
        tester,
        small,
        const CowriteScreen(),
        prepare: (c) => startFlow(c, toCloze: true),
        textScale: 1.3,
      );
    });

    testWidgets('history', (tester) async {
      await check(
        tester,
        small,
        Scaffold(body: HistoryScreen(profile: _student)),
        textScale: 1.3,
      );
    });

    testWidgets('pretest', (tester) async {
      await check(
        tester,
        small,
        const ResearchAssessmentScreen(uid: 'student-1', stage: ResearchStage.preTest),
        overrides: _overrides(
          research: FakeResearchAssessmentService(participant: participantFor()),
          instrument: instrument,
        ),
        textScale: 1.3,
      );
    });

    testWidgets('placement item', (tester) async {
      await check(
        tester,
        small,
        const PlacementTestScreen(uid: 'student-1'),
        overrides: _overrides(placement: FakePlacementService()),
        textScale: 1.3,
        drive: (tester, container) async {
          await container.read(placementTestControllerProvider('student-1').notifier).start();
          await tester.pumpAndSettle();
        },
      );
    });
  });

  group('phones held sideways', () {
    for (final size in const [Size(844, 390), Size(568, 320)]) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';
      cases.forEach((name, home) {
        testWidgets('$name @ $label', (tester) => check(tester, size, home));
      });

      testWidgets('vocabulary filters leave room for the list @ $label', (tester) async {
        await check(
          tester,
          size,
          const VocabBrowserScreen(),
          drive: (tester, _) async {
            await tester.tap(find.text('Tema'));
            await tester.pumpAndSettle();
            // The first word of the list is on screen, not pushed out by filters.
            expect(find.text(_longWord).hitTestable(), findsOneWidget);
          },
        );
      });

      testWidgets('co-write keeps the conversation and the composer usable @ $label', (tester) async {
        await check(
          tester,
          size,
          const CowriteScreen(),
          prepare: (c) => startFlow(c, toCloze: true),
          drive: (tester, _) async {
            expect(find.byType(StepperHeader), findsOneWidget);
            expect(find.byType(TextField).hitTestable(), findsOneWidget);
            expect(find.text('Saran menulis').hitTestable(), findsOneWidget);
            await tester.tap(find.text('Saran menulis'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byType(TextField).hitTestable(), findsOneWidget);
          },
        );
      });

      testWidgets('story @ $label', (tester) async {
        await check(tester, size, const StoryReadingScreen(), prepare: startFlow);
      });

      testWidgets('cloze @ $label', (tester) async {
        await check(
          tester,
          size,
          ClozeTestScreen(random: Random(1)),
          prepare: (c) => startFlow(c, toCloze: true),
        );
      });

      testWidgets('placement item @ $label', (tester) async {
        await check(
          tester,
          size,
          const PlacementTestScreen(uid: 'student-1'),
          overrides: _overrides(placement: FakePlacementService()),
          drive: (tester, container) async {
            await container.read(placementTestControllerProvider('student-1').notifier).start();
            await tester.pumpAndSettle();
            expect(find.text('Berikutnya').hitTestable(), findsOneWidget);
          },
        );
      });

      testWidgets('pretest @ $label', (tester) async {
        await check(
          tester,
          size,
          const ResearchAssessmentScreen(uid: 'student-1', stage: ResearchStage.preTest),
          overrides: _overrides(
            research: FakeResearchAssessmentService(participant: participantFor()),
            instrument: instrument,
          ),
        );
      });
    }
  });

  group('touch targets', () {
    Future<void> expectTargets(WidgetTester tester, Widget home, {Future<void> Function(ProviderContainer)? prepare}) =>
        check(
          tester,
          const Size(390, 844),
          home,
          prepare: prepare,
          drive: (tester, _) async {
            final handle = tester.ensureSemantics();
            await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
            await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
            handle.dispose();
          },
        );

    testWidgets('login', (tester) => expectTargets(tester, const LoginScreen()));
    testWidgets('dashboard', (tester) => expectTargets(tester, cases['student shell']!));
    testWidgets('vocabulary browser', (tester) => expectTargets(tester, const VocabBrowserScreen()));
    testWidgets('placement instructions', (tester) => expectTargets(tester, const PlacementTestScreen(uid: 'student-1')));
    testWidgets('researcher panel', (tester) => expectTargets(tester, cases['researcher panel']!));
  });
}
