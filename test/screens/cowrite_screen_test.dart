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

  /// Application-forced fallback turns; `null` -> throws (Worker failure).
  FutureOr<CowriteTurnResult> Function(String forcedWord)? forcedHandler;

  @override
  Future<CowriteTurnResult> cowriteForcedTurn({
    required List<Map<String, String>> transcript,
    required List<String> remainingWords,
    required String forcedWord,
  }) async {
    final h = forcedHandler;
    if (h == null) throw const AiWorkerException('no forced handler configured');
    return await h(forcedWord);
  }

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
    bool studentTurnContainsIndonesian = false,
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

  testWidgets(
    '"Saran menulis" shows an Indonesian instruction around the English sentence, '
    'without adding a chat bubble',
    (tester) async {
      final ai = _FakeAiWorkerService()
        ..handler = (transcript, remaining, requestSuggestion) {
          expect(requestSuggestion, isTrue);
          return const CowriteTurnResult(
            aiTurn: '',
            feedback: null,
            hasError: false,
            wordsUsedCorrectly: [],
            suggestion: 'I order a cup of coffee.',
            aiUsedWords: [],
          );
        };
      final container = await _pumpCowrite(tester, ai: ai);

      await tester.tap(find.text('Saran menulis'));
      await tester.pumpAndSettle();

      expect(find.text('💡 Coba tulis "I order a cup of coffee."'), findsOneWidget);
      expect(find.textContaining('Try'), findsNothing);
      expect(container.read(learningFlowControllerProvider).cowriteTranscript, isEmpty);
    },
  );

  testWidgets(
    '"Saran menulis" from an older Worker that still prefixes English instructions '
    'is normalized to the Indonesian instruction',
    (tester) async {
      final ai = _FakeAiWorkerService()
        ..handler = (transcript, remaining, requestSuggestion) => const CowriteTurnResult(
              aiTurn: 'ignored',
              feedback: null,
              hasError: false,
              wordsUsedCorrectly: [],
              suggestion: 'Try to write: "I ran to buy a souvenir."',
              aiUsedWords: [],
            );
      await _pumpCowrite(tester, ai: ai);

      await tester.tap(find.text('Saran menulis'));
      await tester.pumpAndSettle();

      expect(find.text('💡 Coba tulis "I ran to buy a souvenir."'), findsOneWidget);
      expect(find.text('ignored'), findsNothing);
    },
  );

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

  testWidgets(
    'Phase 1: submitting a bare word or fragment shows user-visible feedback, '
    'does not add a chat bubble or call the Worker, and preserves the draft in TextField',
    (tester) async {
      var workerCalled = false;
      final ai = _FakeAiWorkerService()
        ..handler = (transcript, remainingWords, requestSuggestion) async {
          workerCalled = true;
          return const CowriteTurnResult(
            aiTurn: 'Great, what happened next?',
            feedback: 'Bagus!',
            hasError: false,
            wordsUsedCorrectly: ['run'],
            suggestion: null,
            aiUsedWords: [],
          );
        };
      await _pumpCowrite(tester, ai: ai);

      // 1. Submit bare word "run"
      await tester.enterText(find.byType(TextField), 'run');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(workerCalled, isFalse);
      expect(find.text(kBareOrFragmentTurnErrorMessage), findsOneWidget);
      // Draft is still in the TextField so the student can edit and resubmit.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'run',
      );
      expect(find.text('Great, what happened next?'), findsNothing);

      // 2. Student edits draft into a full sentence and sends again.
      await tester.enterText(find.byType(TextField), 'I ran to the store.');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(workerCalled, isTrue);
      expect(find.text(kBareOrFragmentTurnErrorMessage), findsNothing);
      expect(find.text('I ran to the store.'), findsOneWidget);
      expect(find.text('Great, what happened next?'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'Bug A: after single or repeated local rejections (e.g. "run", then "the souvenir"), '
    'the composer TextField remains focused, clickable, and editable so the student can '
    'immediately submit a valid sentence',
    (tester) async {
      var workerCallCount = 0;
      final ai = _FakeAiWorkerService()
        ..handler = (transcript, remainingWords, requestSuggestion) async {
          workerCallCount++;
          return const CowriteTurnResult(
            aiTurn: 'What did the cat do next?',
            feedback: 'Kalimat yang bagus!',
            hasError: false,
            wordsUsedCorrectly: ['run'],
            suggestion: null,
            aiUsedWords: [],
          );
        };
      final container = await _pumpCowrite(tester, ai: ai);

      // 1. Focus TextField, type bare target word "run", tap Send.
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'run');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      final textField1 = tester.widget<TextField>(find.byType(TextField));
      expect(workerCallCount, 0);
      expect(container.read(learningFlowControllerProvider).isSendingTurn, isFalse);
      expect(container.read(learningFlowControllerProvider).cowriteTranscript, isEmpty);
      expect(find.text(kBareOrFragmentTurnErrorMessage), findsOneWidget);
      expect(textField1.controller?.text, 'run');
      expect(textField1.enabled, isTrue);
      expect(textField1.focusNode?.hasFocus, isTrue);

      // 2. Repeated local rejection: tap TextField again, enter fragment "the souvenir", tap Send.
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'the souvenir');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      final textField2 = tester.widget<TextField>(find.byType(TextField));
      expect(workerCallCount, 0);
      expect(container.read(learningFlowControllerProvider).isSendingTurn, isFalse);
      expect(container.read(learningFlowControllerProvider).cowriteTranscript, isEmpty);
      expect(find.text(kBareOrFragmentTurnErrorMessage), findsOneWidget);
      expect(textField2.controller?.text, 'the souvenir');
      expect(textField2.enabled, isTrue);
      expect(textField2.focusNode?.hasFocus, isTrue);

      // 3. Immediately tap/edit TextField to a valid sentence and submit.
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus, isTrue);
      await tester.enterText(find.byType(TextField), 'The cat will attack the toy and run.');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(workerCallCount, 1);
      expect(find.text(kBareOrFragmentTurnErrorMessage), findsNothing);
      expect(find.text('The cat will attack the toy and run.'), findsOneWidget);
      expect(find.text('What did the cat do next?'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, isEmpty);
    },
  );

  testWidgets(
    'an ordinary reply without a target word ("Okay.") is sent as a normal turn, not rejected',
    (tester) async {
      var workerCallCount = 0;
      final ai = _FakeAiWorkerService()
        ..handler = (transcript, remainingWords, requestSuggestion) {
          workerCallCount++;
          return const CowriteTurnResult(
            aiTurn: 'Then the door creaked open.',
            feedback: null,
            hasError: false,
            wordsUsedCorrectly: [],
            suggestion: null,
            aiUsedWords: [],
          );
        };
      await _pumpCowrite(tester, ai: ai);

      await tester.enterText(find.byType(TextField), 'Okay.');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(workerCallCount, 1);
      expect(find.text(kBareOrFragmentTurnErrorMessage), findsNothing);
      expect(find.text('Okay.'), findsOneWidget);
      expect(find.text('Then the door creaked open.'), findsOneWidget);
    },
  );

  testWidgets(
    'bot target-word usage lights a pill only through the application-forced fallback '
    '(after 3 missed student turns) — never from an ordinary AI turn — and never '
    'credits student mastery',
    (tester) async {
      final ai = _FakeAiWorkerService()
        ..handler = ((transcript, remainingWords, requestSuggestion) =>
            const CowriteTurnResult(
              // Incidentally contains a target word: must NOT light the pill.
              aiTurn: 'Then she bought a lovely souvenir at the shop.',
              feedback: 'Kalimatmu sudah benar.',
              hasError: false,
              wordsUsedCorrectly: [],
              suggestion: null,
              aiUsedWords: ['souvenir'],
            ))
        ..forcedHandler = (forcedWord) => CowriteTurnResult(
              aiTurn: 'Everyone in the shop talked about the $forcedWord.',
              feedback: null,
              hasError: false,
              wordsUsedCorrectly: const [],
              suggestion: null,
              aiUsedWords: [forcedWord],
            );
      final container = await _pumpCowrite(tester, ai: ai);
      final usedPills = find.descendant(of: find.byType(Wrap), matching: find.byIcon(Icons.check));

      for (var i = 0; i < 2; i++) {
        await tester.enterText(find.byType(TextField), 'She walked into the shop.');
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();
      }
      expect(usedPills, findsNothing);
      expect(container.read(learningFlowControllerProvider).consecutiveMissedStudentTurns, 2);

      await tester.enterText(find.byType(TextField), 'She walked into the shop.');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      final flowState = container.read(learningFlowControllerProvider);
      expect(flowState.allWordsUsedCorrectly, hasLength(1));
      final forcedWord = flowState.allWordsUsedCorrectly.single;
      // The forced bot bubble replaces the ordinary one (6th chat item; may be
      // below the fold of the test viewport, so asserted via state).
      expect(
        flowState.cowriteTranscript.last.text,
        'Everyone in the shop talked about the $forcedWord.',
      );
      expect(flowState.cowriteTranscript, hasLength(6));
      expect(usedPills, findsOneWidget);
      expect(flowState.independentWordsUsedCorrectly, isEmpty);
      expect(flowState.consecutiveMissedStudentTurns, 0);
    },
  );

  testWidgets(
    'Post-response keyboard input: after sending a valid turn and receiving the Worker response, '
    'the focused composer retains an active TextInputConnection and accepts direct keyboard input '
    'across multiple consecutive turns',
    (tester) async {
      var workerCallCount = 0;
      final ai = _FakeAiWorkerService()
        ..handler = (transcript, remainingWords, requestSuggestion) async {
          workerCallCount++;
          return CowriteTurnResult(
            aiTurn: 'AI reply #$workerCallCount: What happened next?',
            feedback: workerCallCount == 1 ? 'Perhatikan bentuk lampau.' : null,
            hasError: workerCallCount == 1,
            wordsUsedCorrectly: const [],
            suggestion: null,
            aiUsedWords: const [],
          );
        };
      final container = await _pumpCowrite(tester, ai: ai);

      // Turn 1: Focus composer, type, and click Send.
      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.testTextInput.enterText('one day a monster came and attack the village');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      final textFieldAfterTurn1 = tester.widget<TextField>(find.byType(TextField));
      expect(workerCallCount, 1);
      expect(textFieldAfterTurn1.enabled, isTrue);
      expect(textFieldAfterTurn1.autofillHints, isNull);
      expect(textFieldAfterTurn1.focusNode?.hasFocus, isTrue);
      expect(textFieldAfterTurn1.controller?.text, isEmpty);
      expect(textFieldAfterTurn1.controller?.selection.isValid, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      // Turn 2: Without tapping TextField again (simulating typing on the physical keyboard
      // while the composer shows a blinking caret), type directly via testTextInput.
      tester.testTextInput.enterText('The villagers tried to run to the hill.');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'The villagers tried to run to the hill.',
      );

      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(workerCallCount, 2);
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      // Turn 3: Again type directly via testTextInput without re-tapping, then send.
      tester.testTextInput.enterText('They found a safe cave behind the trees.');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'They found a safe cave behind the trees.',
      );

      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(workerCallCount, 3);
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      // Turn 4: Confirm typing still inserts characters into the same composer.
      tester.testTextInput.enterText('Finally the hero kept a small stone.');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Finally the hero kept a small stone.',
      );

      final transcript = container.read(learningFlowControllerProvider).cowriteTranscript;
      expect(transcript, hasLength(6)); // 3 student turns + 3 AI turns, no duplicates
    },
  );

  testWidgets(
    'Post-rejection then valid send: after rejecting a bare target word ("run"), editing the '
    'retained draft into a valid sentence, and receiving the Worker response, the composer '
    'still accepts direct keyboard input',
    (tester) async {
      var workerCallCount = 0;
      final ai = _FakeAiWorkerService()
        ..handler = (transcript, remainingWords, requestSuggestion) async {
          workerCallCount++;
          return const CowriteTurnResult(
            aiTurn: 'Suddenly, a brave knight appeared to help them.',
            feedback: 'Coba gunakan bentuk lampau "attacked".',
            hasError: true,
            wordsUsedCorrectly: [],
            suggestion: null,
            aiUsedWords: [],
          );
        };
      final container = await _pumpCowrite(tester, ai: ai);

      // 1. Reject bare target word "run" locally.
      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.testTextInput.enterText('run');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(workerCallCount, 0);
      expect(find.text(kBareOrFragmentTurnErrorMessage), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, 'run');
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);

      // 2. Edit the retained draft directly via keyboard input into a valid sentence and submit.
      tester.testTextInput.enterText('one day a monster came and attack the village');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'one day a monster came and attack the village',
      );
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(workerCallCount, 1);
      expect(find.text(kBareOrFragmentTurnErrorMessage), findsNothing);
      expect(find.text('one day a monster came and attack the village'), findsOneWidget);
      expect(find.text('Suddenly, a brave knight appeared to help them.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      // 3. Immediately type the next message via physical keyboard input without re-entering the screen.
      tester.testTextInput.enterText('The people began to run toward the castle.');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'The people began to run toward the castle.',
      );
      expect(container.read(learningFlowControllerProvider).cowriteTranscript, hasLength(2));
    },
  );

  group('CW-02: feedback indicators', () {
    CowriteTurnResult reply({
      required String feedback,
      List<String> words = const [],
      bool hasError = false,
    }) {
      return CowriteTurnResult(
        aiTurn: 'A cold wind blew through the market.',
        feedback: feedback,
        hasError: hasError,
        wordsUsedCorrectly: words,
        suggestion: null,
        aiUsedWords: const [],
      );
    }

    Future<void> sendWith(WidgetTester tester, CowriteTurnResult result, String text) async {
      final ai = _FakeAiWorkerService()..handler = (transcript, remaining, s) => result;
      await _pumpCowrite(tester, ai: ai);
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
    }

    testWidgets('validated use renders a green check, not a warning', (tester) async {
      await sendWith(
        tester,
        reply(feedback: 'Tepat, "ran" dipakai untuk kejadian lampau.', words: const ['run']),
        'I ran to the store.',
      );

      expect(find.byKey(const ValueKey('cowrite-feedback-positive')), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(Icons.check_circle)).semanticLabel, 'Sudah tepat');
      expect(find.byIcon(Icons.lightbulb), findsNothing);
      expect(find.text('⚠️'), findsNothing);
    });

    testWidgets('an important problem renders an amber lightbulb', (tester) async {
      await sendWith(
        tester,
        reply(
          feedback: '"run" sudah tepat. Seharusnya "ran" karena kejadiannya lampau.',
          words: const ['run'],
          hasError: true,
        ),
        'Yesterday I run to the store.',
      );

      expect(find.byKey(const ValueKey('cowrite-feedback-needsImprovement')), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(Icons.lightbulb)).semanticLabel, 'Perlu perbaikan');
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('no target word renders a neutral message indicator, even for praise text', (
      tester,
    ) async {
      await sendWith(tester, reply(feedback: 'Kalimat yang bagus!'), 'We walked home slowly.');

      expect(find.byKey(const ValueKey('cowrite-feedback-reminder')), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(Icons.chat_bubble_outline)).semanticLabel, 'Pengingat');
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.text('Kalimat yang bagus!'), findsOneWidget);
    });

    testWidgets('the indicator does not change the target-word pills (coverage)', (tester) async {
      await sendWith(
        tester,
        reply(feedback: '"run" sudah tepat. Seharusnya "ran".', words: const ['run'], hasError: true),
        'Yesterday I run to the store.',
      );

      // "run" is covered exactly as for a positive turn.
      expect(
        find.descendant(of: find.byType(Wrap), matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
    });
  });
}

