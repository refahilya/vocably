import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/learning_session.dart';
import 'package:vocably/providers/ai_worker_providers.dart';
import 'package:vocably/providers/history_providers.dart';
import 'package:vocably/providers/learning_session_controller.dart';
import 'package:vocably/screens/student/learning_flow/cowrite_screen.dart';
import 'package:vocably/services/ai_worker_service.dart';
import 'package:vocably/services/learning_progress_service.dart';
import 'package:vocably/services/learning_session_service.dart';
import 'package:vocably/utils/cloze_blanks.dart';

class _FakeAiWorkerService extends AiWorkerService {
  /// `FutureOr`, not a plain synchronous return, so a test can hand back
  /// an un-completed `Future` (e.g. via a `Completer`) to freeze the
  /// Worker round-trip mid-flight and inspect state/UI before it resolves
  /// (Milestone 7 Phase 2 Stage 6 — proving the student's message renders
  /// before the AI response arrives).
  FutureOr<CowriteTurnResult> Function(List<Map<String, String>>, List<String>, bool)? handler;

  @override
  Future<GenerateStoryResult> generateStory({
    required List<String> targetWords,
    required String prompt,
  }) async {
    return GenerateStoryResult(
      story: 'I [[run|ran]] and bought a [[souvenir|souvenir]].',
      translation: 'T',
    );
  }

  @override
  Future<CowriteTurnResult> cowriteTurn({
    required List<Map<String, String>> transcript,
    required List<String> remainingWords,
    required bool requestSuggestion,
  }) async {
    final h = handler;
    if (h == null) throw const AiWorkerException('no handler configured');
    return await h(transcript, remainingWords, requestSuggestion);
  }
}

class _FakeLearningSessionService extends LearningSessionService {
  final completeSessionCalls = <Map<String, dynamic>>[];

  @override
  Future<String> createSession({
    required String studentId,
    required List<String> wordIds,
    required String sourceType,
    required String storyTitle,
    required String storyContent,
    required String? storyTranslation,
  }) async => 'session-1';

  @override
  Future<void> advanceToClozeTest(String sessionId) async {}

  @override
  Future<void> recordClozeResult({
    required String sessionId,
    required Map<String, bool> clozeTestResult,
  }) async {}

  @override
  Future<void> saveCowriteTranscript({
    required String sessionId,
    required List<CowriteTurn> transcript,
  }) async {}

  @override
  Future<void> completeSession({
    required String sessionId,
    required List<CowriteTurn> transcript,
    required List<String> cowriteWordsUsedCorrectly,
  }) async {
    completeSessionCalls.add({
      'sessionId': sessionId,
      'cowriteWordsUsedCorrectly': cowriteWordsUsedCorrectly,
    });
  }
}

class _FakeLearningProgressService extends LearningProgressService {
  final recordCowriteCompletionCalls = <Map<String, dynamic>>[];
  bool throwOnRecordCowriteCompletion = false;

  @override
  Future<void> recordClozeCompletion({
    required String studentId,
    required List<String> wordIds,
    required String sessionId,
  }) async {}

  @override
  Future<void> recordCowriteCompletion({
    required String studentId,
    required Map<String, bool> clozeTestResult,
    required List<String> cowriteWordsUsedCorrectly,
    required String sessionId,
  }) async {
    if (throwOnRecordCowriteCompletion) {
      throw Exception('permission-denied (simulated)');
    }
    recordCowriteCompletionCalls.add({
      'studentId': studentId,
      'cowriteWordsUsedCorrectly': cowriteWordsUsedCorrectly,
    });
  }
}

Future<ProviderContainer> _pumpCowrite(
  WidgetTester tester, {
  required _FakeAiWorkerService ai,
  _FakeLearningSessionService? sessionService,
  _FakeLearningProgressService? progressService,
}) async {
  final container = ProviderContainer(
    overrides: [
      aiWorkerServiceProvider.overrideWithValue(ai),
      learningSessionServiceProvider.overrideWithValue(
        sessionService ?? _FakeLearningSessionService(),
      ),
      learningProgressServiceProvider.overrideWithValue(
        progressService ?? _FakeLearningProgressService(),
      ),
    ],
  );
  final controller = container.read(learningFlowControllerProvider.notifier);
  controller.startFlow(
    studentId: 'student-1',
    wordIds: ['run', 'souvenir'],
    sourceType: LearningSessionSourceType.targetGuru,
  );
  await controller.generateStory(prompt: 'judul');
  await controller.advanceToClozeTest();
  final segments = buildClozeSegments(container.read(learningFlowControllerProvider).storyContent!);
  controller.setClozeAnswer('run', 'run');
  controller.setClozeAnswer('souvenir', 'souvenir');
  controller.submitCloze();
  await controller.confirmClozeAndAdvance(segments);

  final innerNavigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Navigator(
          key: innerNavigatorKey,
          onGenerateRoute: (_) =>
              MaterialPageRoute(builder: (_) => const Text('Origin screen')),
        ),
      ),
    ),
  );
  // Push CowriteScreen on top of an "origin" first route, so popUntil(first)
  // in the real "Selesai" handler has somewhere real to land.
  innerNavigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const CowriteScreen()));
  await tester.pumpAndSettle();

  return container;
}

void main() {
  testWidgets('shows every target word as an unused pill initially', (tester) async {
    await _pumpCowrite(tester, ai: _FakeAiWorkerService());

    expect(find.text('run'), findsOneWidget);
    expect(find.text('souvenir'), findsOneWidget);
    // The stepper header also has its own "completed step" checkmarks
    // (Membaca/Cloze Test are both done by this point) — scope the
    // "used" check to just the target-word pill row.
    expect(
      find.descendant(of: find.byType(Wrap), matching: find.byIcon(Icons.check)),
      findsNothing,
    );
  });

  testWidgets('sending a turn appends chat bubbles and marks the used word', (tester) async {
    final ai = _FakeAiWorkerService()
      ..handler = (transcript, remaining, requestSuggestion) => const CowriteTurnResult(
        aiTurn: 'What did you do next?',
        feedback: 'Nice sentence!',
        hasError: false,
        wordsUsedCorrectly: ['run'],
        suggestion: null,
        aiUsedWords: [],
      );
    await _pumpCowrite(tester, ai: ai);

    await tester.enterText(find.byType(TextField), 'I ran to the store.');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('I ran to the store.'), findsOneWidget);
    expect(find.text('What did you do next?'), findsOneWidget);
    expect(find.text('Nice sentence!'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Wrap), matching: find.byIcon(Icons.check)),
      findsOneWidget, // "run" pill now used
    );
  });

  testWidgets('"Saran menulis" shows a suggestion without adding a chat bubble', (tester) async {
    final ai = _FakeAiWorkerService()
      ..handler = (transcript, remaining, requestSuggestion) {
        expect(requestSuggestion, isTrue);
        return const CowriteTurnResult(
          aiTurn: 'ignored',
          feedback: null,
          hasError: false,
          wordsUsedCorrectly: [],
          suggestion: 'Try: I ran to buy a souvenir.',
          aiUsedWords: [],
        );
      };
    await _pumpCowrite(tester, ai: ai);

    await tester.tap(find.text('Saran menulis'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Try: I ran to buy a souvenir.'), findsOneWidget);
    expect(find.text('ignored'), findsNothing);
  });

  testWidgets(
    'once all words are used, the finish banner replaces the composer; "Selesai" '
    'completes the session and returns to the origin screen',
    (tester) async {
      final ai = _FakeAiWorkerService()
        ..handler = (transcript, remaining, requestSuggestion) =>
            CowriteTurnResult(
              aiTurn: 'Great!',
              feedback: null,
              hasError: false,
              wordsUsedCorrectly: [...remaining],
              suggestion: null,
              aiUsedWords: const [],
            );
      final sessionService = _FakeLearningSessionService();
      final progressService = _FakeLearningProgressService();
      await _pumpCowrite(
        tester,
        ai: ai,
        sessionService: sessionService,
        progressService: progressService,
      );

      await tester.enterText(find.byType(TextField), 'I ran and bought a souvenir.');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('🎉 Selamat! Semua kata target sudah digunakan!'), findsOneWidget);
      expect(find.text('✓ Selesai'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('✓ Selesai'));
      await tester.pumpAndSettle();

      expect(sessionService.completeSessionCalls, hasLength(1));
      expect(
        (sessionService.completeSessionCalls.single['cowriteWordsUsedCorrectly'] as List<String>)
            .toSet(),
        {'run', 'souvenir'},
      );
      expect(progressService.recordCowriteCompletionCalls, hasLength(1));
      expect(find.text('Origin screen'), findsOneWidget);
      expect(find.byType(CowriteScreen), findsNothing);
    },
  );

  testWidgets(
    'Stage 3: a failed write on "Selesai" stays on the co-write screen, shows an '
    'error, and does NOT navigate away — the exact reported permission-denied bug',
    (tester) async {
      final ai = _FakeAiWorkerService()
        ..handler = (transcript, remaining, requestSuggestion) =>
            CowriteTurnResult(
              aiTurn: 'Great!',
              feedback: null,
              hasError: false,
              wordsUsedCorrectly: [...remaining],
              suggestion: null,
              aiUsedWords: const [],
            );
      final sessionService = _FakeLearningSessionService();
      final progressService = _FakeLearningProgressService()
        ..throwOnRecordCowriteCompletion = true;
      await _pumpCowrite(
        tester,
        ai: ai,
        sessionService: sessionService,
        progressService: progressService,
      );

      await tester.enterText(find.byType(TextField), 'I ran and bought a souvenir.');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      await tester.tap(find.text('✓ Selesai'));
      await tester.pumpAndSettle();

      // completeSession() (the learningSessions write) already succeeded —
      // this reproduces the exact reported bug: recordCowriteCompletion()
      // throws (learningProgress permission-denied), and previously that
      // exception was unhandled, silently blocking the navigation with no
      // feedback at all.
      expect(sessionService.completeSessionCalls, hasLength(1));
      expect(progressService.recordCowriteCompletionCalls, isEmpty);
      expect(find.byType(CowriteScreen), findsOneWidget);
      expect(find.text('Origin screen'), findsNothing);
      expect(find.text('Gagal menyelesaikan sesi. Coba lagi.'), findsOneWidget);
      // Still retryable — the finish banner and its button are still there.
      expect(find.text('✓ Selesai'), findsOneWidget);
    },
  );

  testWidgets(
    'Stage 6: the student\'s message appears immediately after Send, before the '
    'AI response arrives — and the AI turn appears once it resolves',
    (tester) async {
      final aiResponseCompleter = Completer<CowriteTurnResult>();
      final ai = _FakeAiWorkerService()
        ..handler = (transcript, remainingWords, requestSuggestion) =>
            aiResponseCompleter.future;
      await _pumpCowrite(tester, ai: ai);

      await tester.enterText(find.byType(TextField), 'I ran today.');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(); // one frame only — the Worker call is still pending

      // The student's own message is already visible...
      expect(find.text('I ran today.'), findsOneWidget);
      // ...while the AI is still "typing" (the send button shows its
      // sending spinner, and there is no AI reply yet).
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Great, what happened next?'), findsNothing);

      aiResponseCompleter.complete(
        const CowriteTurnResult(
          aiTurn: 'Great, what happened next?',
          feedback: null,
          hasError: false,
          wordsUsedCorrectly: [],
          suggestion: null,
          aiUsedWords: [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('I ran today.'), findsOneWidget);
      expect(find.text('Great, what happened next?'), findsOneWidget);
    },
  );

  testWidgets(
    'Stage 6: a failed send rolls the optimistically-shown message back — the '
    'existing "no trace left" contract is preserved once the failure settles',
    (tester) async {
      final ai = _FakeAiWorkerService(); // handler null -> always throws
      await _pumpCowrite(tester, ai: ai);

      await tester.enterText(find.byType(TextField), 'I ran today.');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('I ran today.'), findsNothing);
      expect(find.text('Gagal mengirim giliran. Coba lagi.'), findsOneWidget);
    },
  );
}
