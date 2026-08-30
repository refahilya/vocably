import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/app_user.dart';
import 'package:vocably/models/learning_progress.dart';
import 'package:vocably/models/learning_session.dart';
import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/models/vocab_word.dart';
import 'package:vocably/providers/history_providers.dart';
import 'package:vocably/providers/vocab_bundle_providers.dart';
import 'package:vocably/screens/student/history/history_screen.dart';
import 'package:vocably/screens/student/history/session_detail_screen.dart';
import 'package:vocably/services/learning_progress_service.dart';
import 'package:vocably/services/learning_session_service.dart';
import 'package:vocably/services/vocab_bundle_service.dart';
import 'package:vocably/utils/role.dart';

class _FakeLearningProgressService extends LearningProgressService {
  List<LearningProgress> rows = [];

  @override
  Future<List<LearningProgress>> fetchForStudent(String studentId) async => rows;
}

class _FakeLearningSessionService extends LearningSessionService {
  List<LearningSession> sessions = [];

  @override
  Future<List<LearningSession>> fetchForStudent(String studentId) async => sessions;
}

/// Simulates a real Firestore failure (a bad document shape, a rules
/// mismatch, a network error) — whatever the actual cause, this proves
/// the UI never silently drops it.
class _ThrowingLearningSessionService extends LearningSessionService {
  @override
  Future<List<LearningSession>> fetchForStudent(String studentId) {
    throw Exception('simulated learningSessions failure (e.g. a bad document shape)');
  }
}

class _ThrowingLearningProgressService extends LearningProgressService {
  @override
  Future<List<LearningProgress>> fetchForStudent(String studentId) {
    throw Exception('simulated learningProgress failure');
  }
}

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
);

LearningProgress _progress({required String wordId, required String masteryStatus}) {
  return LearningProgress(
    studentId: 'student-1',
    wordId: wordId,
    learnedStatus: LearnedStatus.sudahDipelajari,
    masteryStatus: masteryStatus,
    firstLearnedAt: DateTime(2026, 1, 1),
    lastUpdatedAt: DateTime(2026, 1, 2),
    lastSessionId: 'session-1',
  );
}

Future<void> _pumpHistory(
  WidgetTester tester, {
  LearningProgressService? progressService,
  LearningSessionService? sessionService,
  _FakeVocabBundleService? bundleService,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        learningProgressServiceProvider.overrideWithValue(
          progressService ?? _FakeLearningProgressService(),
        ),
        learningSessionServiceProvider.overrideWithValue(
          sessionService ?? _FakeLearningSessionService(),
        ),
        vocabBundleServiceProvider.overrideWithValue(bundleService ?? _FakeVocabBundleService()),
      ],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Harness')),
          body: HistoryScreen(profile: _studentProfile),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('HistoryScreen — Per Kata tab', () {
    testWidgets('shows the empty state when nothing has been learned yet', (tester) async {
      await _pumpHistory(tester);
      expect(find.text('Belum ada kata yang dipelajari'), findsOneWidget);
    });

    testWidgets('shows resolved words with mastery badges, filterable by label', (tester) async {
      final progressService = _FakeLearningProgressService()
        ..rows = [
          _progress(wordId: 'run', masteryStatus: MasteryStatus.mastered),
          _progress(wordId: 'souvenir', masteryStatus: MasteryStatus.difficult),
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
              meanings: const [VocabMeaning(pos: 'noun', translation: 'oleh-oleh')],
              cefrLevel: 'A1',
              topics: const [],
            ),
          ],
        };

      await _pumpHistory(tester, progressService: progressService, bundleService: bundleService);

      expect(find.text('run'), findsOneWidget);
      expect(find.text('souvenir'), findsOneWidget);

      await tester.tap(find.text('Difficult'));
      await tester.pumpAndSettle();

      expect(find.text('souvenir'), findsOneWidget);
      expect(find.text('run'), findsNothing);
      expect(find.text('Pelajari Kembali'), findsOneWidget);

      // Milestone 7: tapping it starts a re-learn flow with exactly the
      // words currently shown by the `difficult` filter (Decision 2 — no
      // per-word checkbox selection).
      final relearnButton = tester.widget<FilledButton>(
        find.ancestor(of: find.text('Pelajari Kembali'), matching: find.byType(FilledButton)),
      );
      expect(relearnButton.onPressed, isNotNull);

      await tester.tap(find.text('Pelajari Kembali'));
      await tester.pumpAndSettle();

      expect(find.text('Baca Cerita'), findsOneWidget);
    });

    testWidgets('filtering to difficult with none found shows the positive empty state', (
      tester,
    ) async {
      final progressService = _FakeLearningProgressService()
        ..rows = [_progress(wordId: 'run', masteryStatus: MasteryStatus.mastered)];
      final bundleService = _FakeVocabBundleService()
        ..byLevel = {
          'A1': [
            VocabBundleEntry(
              word: 'run',
              meanings: const [VocabMeaning(pos: 'verb', translation: 'lari')],
              cefrLevel: 'A1',
              topics: const [],
            ),
          ],
        };

      await _pumpHistory(tester, progressService: progressService, bundleService: bundleService);

      await tester.tap(find.text('Difficult'));
      await tester.pumpAndSettle();

      expect(find.text('Tidak ada kata yang perlu diulang'), findsOneWidget);
    });
  });

  group('HistoryScreen — Per Sesi tab', () {
    testWidgets('shows the empty state when no sessions exist yet', (tester) async {
      await _pumpHistory(tester);

      await tester.tap(find.text('Per Sesi'));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada kata yang dipelajari'), findsOneWidget);
    });

    testWidgets('shows a session card and opens the story replay on tap', (tester) async {
      final sessionService = _FakeLearningSessionService()
        ..sessions = [
          LearningSession(
            id: 'session-1',
            studentId: 'student-1',
            wordIds: const ['run'],
            sourceType: LearningSessionSourceType.keranjangPelajari,
            currentPhase: LearningSessionPhase.selesai,
            storyTitle: 'Liburan',
            storyContent: 'I [[run|ran]] to the park.',
            storyTranslation: 'Saya berlari ke taman.',
            clozeTestResult: const {'run': true},
            cowriteTranscript: const [],
            cowriteWordsUsedCorrectly: const ['run'],
            startedAt: DateTime(2026, 8, 1, 10, 0),
            completedAt: DateTime(2026, 8, 1, 10, 30),
          ),
        ];

      await _pumpHistory(tester, sessionService: sessionService);

      await tester.tap(find.text('Per Sesi'));
      await tester.pumpAndSettle();

      expect(find.text('1/8/2026 10:00'), findsOneWidget);
      expect(find.text('1 kata'), findsOneWidget);

      await tester.tap(find.text('1/8/2026 10:00'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionDetailScreen), findsOneWidget);
      expect(find.text('Liburan'), findsWidgets);
      expect(find.textContaining('ran'), findsOneWidget);

      await tester.tap(find.text('Terjemahan'));
      await tester.pumpAndSettle();

      expect(find.text('Saya berlari ke taman.'), findsOneWidget);
    });
  });

  group('HistoryScreen — error handling does not silently swallow the exception', () {
    // Regression coverage for a real bug: `error: (error, stackTrace) =>
    // _ErrorRetry(...)` used to discard `error`/`stackTrace` completely,
    // so a genuine Firestore failure left literally no trace anywhere —
    // "Gagal memuat riwayat." was the only observable symptom, with no
    // way to diagnose it from a running app. These tests fail against
    // that old code (nothing captured below) and pass now that the
    // error/stackTrace get `debugPrint`ed before the friendly fallback
    // renders.
    //
    // `debugPrint` is swapped and restored *inside* each test body
    // (not via setUp/tearDown) — flutter_test's `_verifyInvariants`
    // asserts every foundation debug variable is back to its original
    // value by the moment the test callback itself returns, which runs
    // before a tearDown callback would fire.
    testWidgets(
      'Per Sesi: a thrown exception is logged (not swallowed) and the UI still shows the friendly message, never the raw exception',
      (tester) async {
        final originalDebugPrint = debugPrint;
        final capturedDebugPrints = <String>[];
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) capturedDebugPrints.add(message);
        };

        try {
          await _pumpHistory(tester, sessionService: _ThrowingLearningSessionService());

          await tester.tap(find.text('Per Sesi'));
          await tester.pumpAndSettle();

          // Friendly fallback shown — DESIGN_REFERENCE.md §5.8: never a
          // raw error to the student.
          expect(find.text('Gagal memuat riwayat.'), findsOneWidget);
          expect(
            find.textContaining('simulated learningSessions failure'),
            findsNothing,
          );

          // But the real exception was NOT silently dropped — it reached
          // the developer-facing debug log.
          expect(
            capturedDebugPrints.any(
              (line) => line.contains('simulated learningSessions failure'),
            ),
            isTrue,
            reason:
                'the underlying exception should be debugPrint-ed, not silently swallowed',
          );
        } finally {
          debugPrint = originalDebugPrint;
        }
      },
    );

    testWidgets(
      'Per Kata: a thrown exception is logged (not swallowed) and the UI still shows the friendly message, never the raw exception',
      (tester) async {
        final originalDebugPrint = debugPrint;
        final capturedDebugPrints = <String>[];
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) capturedDebugPrints.add(message);
        };

        try {
          await _pumpHistory(tester, progressService: _ThrowingLearningProgressService());
          await tester.pumpAndSettle();

          expect(find.text('Gagal memuat riwayat.'), findsOneWidget);
          expect(find.textContaining('simulated learningProgress failure'), findsNothing);
          expect(
            capturedDebugPrints.any(
              (line) => line.contains('simulated learningProgress failure'),
            ),
            isTrue,
            reason:
                'the underlying exception should be debugPrint-ed, not silently swallowed',
          );
        } finally {
          debugPrint = originalDebugPrint;
        }
      },
    );
  });
}
