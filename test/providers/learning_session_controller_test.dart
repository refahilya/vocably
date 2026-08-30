import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/learning_session.dart';
import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/providers/ai_worker_providers.dart';
import 'package:vocably/providers/history_providers.dart';
import 'package:vocably/providers/learning_cart_providers.dart';
import 'package:vocably/providers/learning_session_controller.dart';
import 'package:vocably/services/ai_worker_service.dart';
import 'package:vocably/services/learning_progress_service.dart';
import 'package:vocably/services/learning_session_service.dart';
import 'package:vocably/utils/cloze_blanks.dart';

/// Records every call so tests can assert exactly what was sent to
/// Firestore, without a real Firestore/emulator (same disclosed-gap
/// convention as `VocabWordService`/`TargetWordSetService`'s existing
/// tests — see `PROJECT_STATE.md` §5g).
class _FakeLearningSessionService extends LearningSessionService {
  final createCalls = <Map<String, dynamic>>[];
  final overwriteStoryCalls = <Map<String, dynamic>>[];
  final advancePhaseCalls = <String>[];
  final recordClozeResultCalls = <Map<String, dynamic>>[];
  final saveCowriteTranscriptCalls = <Map<String, dynamic>>[];
  final completeSessionCalls = <Map<String, dynamic>>[];

  String nextSessionId = 'session-1';
  bool throwOnCompleteSession = false;

  @override
  Future<String> createSession({
    required String studentId,
    required List<String> wordIds,
    required String sourceType,
    required String storyTitle,
    required String storyContent,
    required String? storyTranslation,
  }) async {
    createCalls.add({
      'studentId': studentId,
      'wordIds': wordIds,
      'sourceType': sourceType,
      'storyTitle': storyTitle,
      'storyContent': storyContent,
      'storyTranslation': storyTranslation,
    });
    return nextSessionId;
  }

  @override
  Future<void> overwriteStory({
    required String sessionId,
    required String storyTitle,
    required String storyContent,
    required String? storyTranslation,
  }) async {
    overwriteStoryCalls.add({
      'sessionId': sessionId,
      'storyTitle': storyTitle,
      'storyContent': storyContent,
      'storyTranslation': storyTranslation,
    });
  }

  bool throwOnAdvanceToClozeTest = false;

  @override
  Future<void> advanceToClozeTest(String sessionId) async {
    if (throwOnAdvanceToClozeTest) {
      throw Exception('simulated Firestore failure');
    }
    advancePhaseCalls.add(sessionId);
  }

  @override
  Future<void> recordClozeResult({
    required String sessionId,
    required Map<String, bool> clozeTestResult,
  }) async {
    recordClozeResultCalls.add({'sessionId': sessionId, 'clozeTestResult': clozeTestResult});
  }

  @override
  Future<void> saveCowriteTranscript({
    required String sessionId,
    required List<CowriteTurn> transcript,
  }) async {
    saveCowriteTranscriptCalls.add({'sessionId': sessionId, 'transcript': transcript});
  }

  @override
  Future<void> completeSession({
    required String sessionId,
    required List<CowriteTurn> transcript,
    required List<String> cowriteWordsUsedCorrectly,
  }) async {
    if (throwOnCompleteSession) {
      throw Exception('simulated Firestore failure');
    }
    completeSessionCalls.add({
      'sessionId': sessionId,
      'transcript': transcript,
      'cowriteWordsUsedCorrectly': cowriteWordsUsedCorrectly,
    });
  }
}

class _FakeLearningProgressService extends LearningProgressService {
  final recordClozeCompletionCalls = <Map<String, dynamic>>[];
  final recordCowriteCompletionCalls = <Map<String, dynamic>>[];
  bool throwOnRecordClozeCompletion = false;
  bool throwOnRecordCowriteCompletion = false;

  @override
  Future<void> recordClozeCompletion({
    required String studentId,
    required List<String> wordIds,
    required String sessionId,
  }) async {
    if (throwOnRecordClozeCompletion) {
      throw Exception('simulated Firestore failure');
    }
    recordClozeCompletionCalls.add({
      'studentId': studentId,
      'wordIds': wordIds,
      'sessionId': sessionId,
    });
  }

  @override
  Future<void> recordCowriteCompletion({
    required String studentId,
    required Map<String, bool> clozeTestResult,
    required List<String> cowriteWordsUsedCorrectly,
    required String sessionId,
  }) async {
    if (throwOnRecordCowriteCompletion) {
      throw Exception('simulated permission-denied on learningProgress');
    }
    recordCowriteCompletionCalls.add({
      'studentId': studentId,
      'clozeTestResult': clozeTestResult,
      'cowriteWordsUsedCorrectly': cowriteWordsUsedCorrectly,
      'sessionId': sessionId,
    });
  }
}

/// Canned/controllable responses, and failure toggles, for both
/// `/generate-story` and `/cowrite-turn` — never touches the real Worker.
class _FakeAiWorkerService extends AiWorkerService {
  GenerateStoryResult Function(List<String> targetWords, String prompt)? generateStoryHandler;
  CowriteTurnResult Function(
    List<Map<String, String>> transcript,
    List<String> remainingWords,
    bool requestSuggestion,
  )?
  cowriteTurnHandler;

  @override
  Future<GenerateStoryResult> generateStory({
    required List<String> targetWords,
    required String prompt,
  }) async {
    final handler = generateStoryHandler;
    if (handler == null) {
      throw const AiWorkerException('no handler configured');
    }
    return handler(targetWords, prompt);
  }

  @override
  Future<CowriteTurnResult> cowriteTurn({
    required List<Map<String, String>> transcript,
    required List<String> remainingWords,
    required bool requestSuggestion,
  }) async {
    final handler = cowriteTurnHandler;
    if (handler == null) {
      throw const AiWorkerException('no handler configured');
    }
    return handler(transcript, remainingWords, requestSuggestion);
  }
}

void main() {
  late _FakeAiWorkerService fakeAi;
  late _FakeLearningSessionService fakeSessionService;
  late _FakeLearningProgressService fakeProgressService;
  late ProviderContainer container;

  setUp(() {
    fakeAi = _FakeAiWorkerService();
    fakeSessionService = _FakeLearningSessionService();
    fakeProgressService = _FakeLearningProgressService();
    container = ProviderContainer(
      overrides: [
        aiWorkerServiceProvider.overrideWithValue(fakeAi),
        learningSessionServiceProvider.overrideWithValue(fakeSessionService),
        learningProgressServiceProvider.overrideWithValue(fakeProgressService),
      ],
    );
    addTearDown(container.dispose);
  });

  LearningFlowController controller() =>
      container.read(learningFlowControllerProvider.notifier);
  LearningFlowState state() => container.read(learningFlowControllerProvider);

  group('startFlow', () {
    test('dedupes by normalizeWord(), preserving first-seen order', () {
      controller().startFlow(
        studentId: 'student-1',
        wordIds: ['Run', 'run ', 'Souvenir', 'RUN'],
        sourceType: LearningSessionSourceType.keranjangPelajari,
      );

      expect(state().wordIds, ['run', 'souvenir']);
      expect(state().studentId, 'student-1');
      expect(state().sessionId, isNull);
      expect(state().currentPhase, LearningSessionPhase.membaca);
    });
  });

  group('generateStory', () {
    test('first successful generate creates a session and populates the story', () async {
      controller().startFlow(
        studentId: 'student-1',
        wordIds: ['run'],
        sourceType: LearningSessionSourceType.targetGuru,
      );
      fakeAi.generateStoryHandler = (words, prompt) => GenerateStoryResult(
        story: 'I [[run|ran]] today.',
        translation: 'Saya berlari hari ini.',
      );

      await controller().generateStory(prompt: 'liburan');

      expect(fakeSessionService.createCalls, hasLength(1));
      expect(fakeSessionService.createCalls.single['studentId'], 'student-1');
      expect(fakeSessionService.createCalls.single['wordIds'], ['run']);
      expect(
        fakeSessionService.createCalls.single['sourceType'],
        LearningSessionSourceType.targetGuru,
      );
      expect(state().sessionId, 'session-1');
      expect(state().storyContent, 'I [[run|ran]] today.');
      expect(state().storyTranslation, 'Saya berlari hari ini.');
      expect(state().isGenerating, isFalse);
      expect(state().generateError, isNull);
    });

    test('a second generate overwrites the story instead of creating a new session', () async {
      controller().startFlow(
        studentId: 'student-1',
        wordIds: ['run'],
        sourceType: LearningSessionSourceType.targetGuru,
      );
      fakeAi.generateStoryHandler = (words, prompt) =>
          GenerateStoryResult(story: 'Story A [[run|ran]].', translation: 'A');
      await controller().generateStory(prompt: 'judul A');

      fakeAi.generateStoryHandler = (words, prompt) =>
          GenerateStoryResult(story: 'Story B [[run|running]].', translation: 'B');
      await controller().generateStory(prompt: 'judul B');

      expect(fakeSessionService.createCalls, hasLength(1));
      expect(fakeSessionService.overwriteStoryCalls, hasLength(1));
      expect(fakeSessionService.overwriteStoryCalls.single['sessionId'], 'session-1');
      expect(state().storyContent, 'Story B [[run|running]].');
    });

    test(
      'Decision 4: clears the learning cart only once the FIRST generate succeeds, '
      'for a keranjangPelajari flow',
      () async {
        final cartEntry = VocabBundleEntry.fromMap({
          'word': 'run',
          'meanings': [
            {'pos': 'verb', 'translation': 'lari'},
          ],
          'posList': [],
          'cefrLevel': 'A1',
          'topics': [],
        });
        container.read(learningCartProvider.notifier).add(cartEntry);

        controller().startFlow(
          studentId: 'student-1',
          wordIds: ['run'],
          sourceType: LearningSessionSourceType.keranjangPelajari,
        );
        fakeAi.generateStoryHandler = (words, prompt) =>
            GenerateStoryResult(story: 'I [[run|ran]].', translation: 'T');

        await controller().generateStory(prompt: 'judul');

        expect(container.read(learningCartProvider), isEmpty);
      },
    );

    test('does NOT clear the cart for a targetGuru flow', () async {
      final cartEntry = VocabBundleEntry.fromMap({
        'word': 'apple',
        'meanings': [
          {'pos': 'noun', 'translation': 'apel'},
        ],
        'posList': [],
        'cefrLevel': 'A1',
        'topics': [],
      });
      container.read(learningCartProvider.notifier).add(cartEntry);

      controller().startFlow(
        studentId: 'student-1',
        wordIds: ['run'],
        sourceType: LearningSessionSourceType.targetGuru,
      );
      fakeAi.generateStoryHandler = (words, prompt) =>
          GenerateStoryResult(story: 'I [[run|ran]].', translation: 'T');

      await controller().generateStory(prompt: 'judul');

      expect(container.read(learningCartProvider), isNotEmpty);
    });

    test(
      'a failed generate sets a friendly error, creates no session, and leaves the '
      'cart intact (Decision 4)',
      () async {
        final cartEntry = VocabBundleEntry.fromMap({
          'word': 'run',
          'meanings': [
            {'pos': 'verb', 'translation': 'lari'},
          ],
          'posList': [],
          'cefrLevel': 'A1',
          'topics': [],
        });
        container.read(learningCartProvider.notifier).add(cartEntry);

        controller().startFlow(
          studentId: 'student-1',
          wordIds: ['run'],
          sourceType: LearningSessionSourceType.keranjangPelajari,
        );
        fakeAi.generateStoryHandler = null; // -> throws AiWorkerException

        await controller().generateStory(prompt: 'judul');

        expect(fakeSessionService.createCalls, isEmpty);
        expect(state().sessionId, isNull);
        expect(state().isGenerating, isFalse);
        expect(state().generateError, isNotNull);
        expect(container.read(learningCartProvider), isNotEmpty);
      },
    );

    test(
      'Stage 2: a story with a mismatched/hallucinated marker is rejected before any '
      'Firestore write — creates no session, sets a friendly error, story-content stays '
      'null',
      () async {
        controller().startFlow(
          studentId: 'student-1',
          wordIds: ['run'],
          sourceType: LearningSessionSourceType.targetGuru,
        );
        // "souvenir" was never requested — a hallucinated marker.
        fakeAi.generateStoryHandler = (words, prompt) => GenerateStoryResult(
          story: 'I [[run|ran]] and grabbed a [[souvenir|souvenir]].',
          translation: 'T',
        );

        await controller().generateStory(prompt: 'liburan');

        expect(fakeSessionService.createCalls, isEmpty);
        expect(fakeSessionService.overwriteStoryCalls, isEmpty);
        expect(state().sessionId, isNull);
        expect(state().storyContent, isNull);
        expect(state().isGenerating, isFalse);
        expect(
          state().generateError,
          'Cerita yang dihasilkan tidak sesuai dengan kata target. Coba generate ulang.',
        );
      },
    );

    test(
      'Stage 2: a mismatched marker on a REGENERATE is also rejected — the previous '
      'valid story is left untouched, not overwritten with the bad one',
      () async {
        controller().startFlow(
          studentId: 'student-1',
          wordIds: ['run'],
          sourceType: LearningSessionSourceType.targetGuru,
        );
        fakeAi.generateStoryHandler = (words, prompt) =>
            GenerateStoryResult(story: 'I [[run|ran]] today.', translation: 'A');
        await controller().generateStory(prompt: 'judul A');

        // Regenerate: this time the marker is a duplicate.
        fakeAi.generateStoryHandler = (words, prompt) => GenerateStoryResult(
          story: 'I [[run|ran]] here, then [[run|ran]] there.',
          translation: 'B',
        );
        await controller().generateStory(prompt: 'judul B');

        expect(fakeSessionService.createCalls, hasLength(1)); // only the first, good generate
        expect(fakeSessionService.overwriteStoryCalls, isEmpty);
        expect(state().storyContent, 'I [[run|ran]] today.'); // unchanged from the good generate
        expect(state().generateError, isNotNull);
      },
    );

    test(
      'Stage 7: generateStory is a no-op once currentPhase has moved past membaca '
      '(Back → Reading → Generate/Generate Ulang) — the story is locked, no '
      'overwriteStory() attempt is made',
      () async {
        controller().startFlow(
          studentId: 'student-1',
          wordIds: ['run'],
          sourceType: LearningSessionSourceType.targetGuru,
        );
        fakeAi.generateStoryHandler = (words, prompt) =>
            GenerateStoryResult(story: 'I [[run|ran]].', translation: 'T');
        await controller().generateStory(prompt: 'judul');
        await controller().advanceToClozeTest();
        expect(state().currentPhase, LearningSessionPhase.clozeTest);

        // Simulates: student pressed Back to the (now phase-locked)
        // Reading screen and tapped Generate/Generate Ulang again.
        await controller().generateStory(prompt: 'judul baru');

        expect(fakeSessionService.overwriteStoryCalls, isEmpty);
        expect(fakeSessionService.createCalls, hasLength(1)); // only the original create
        expect(state().storyContent, 'I [[run|ran]].'); // unchanged
        expect(state().isGenerating, isFalse);
        expect(state().currentPhase, LearningSessionPhase.clozeTest); // unchanged
      },
    );
  });

  group('advanceToClozeTest', () {
    test('moves the phase forward without touching story fields', () async {
      controller().startFlow(
        studentId: 'student-1',
        wordIds: ['run'],
        sourceType: LearningSessionSourceType.targetGuru,
      );
      fakeAi.generateStoryHandler = (words, prompt) =>
          GenerateStoryResult(story: 'I [[run|ran]].', translation: 'T');
      await controller().generateStory(prompt: 'judul');

      await controller().advanceToClozeTest();

      expect(fakeSessionService.advancePhaseCalls, ['session-1']);
      expect(state().currentPhase, LearningSessionPhase.clozeTest);
    });

    test(
      'Stage 6: a failed write sets advanceToClozeError and does NOT advance the '
      'phase',
      () async {
        controller().startFlow(
          studentId: 'student-1',
          wordIds: ['run'],
          sourceType: LearningSessionSourceType.targetGuru,
        );
        fakeAi.generateStoryHandler = (words, prompt) =>
            GenerateStoryResult(story: 'I [[run|ran]].', translation: 'T');
        await controller().generateStory(prompt: 'judul');
        fakeSessionService.throwOnAdvanceToClozeTest = true;

        await controller().advanceToClozeTest();

        expect(state().advanceToClozeError, 'Gagal melanjutkan ke Cloze Test. Coba lagi.');
        expect(state().currentPhase, LearningSessionPhase.membaca); // never advanced
        expect(state().storyContent, isNotNull); // the valid story is untouched
      },
    );

    test(
      'Stage 7: calling advanceToClozeTest again once already past membaca (Back → '
      'Reading → Selanjutnya) is a no-op that skips the Firestore write and leaves '
      'no error — the caller can navigate straight on',
      () async {
        controller().startFlow(
          studentId: 'student-1',
          wordIds: ['run'],
          sourceType: LearningSessionSourceType.targetGuru,
        );
        fakeAi.generateStoryHandler = (words, prompt) =>
            GenerateStoryResult(story: 'I [[run|ran]].', translation: 'T');
        await controller().generateStory(prompt: 'judul');
        await controller().advanceToClozeTest();
        expect(fakeSessionService.advancePhaseCalls, hasLength(1));

        // Simulates: student pressed Back from ClozeTestScreen (a pure
        // local Navigator.pop — LearningFlowState.currentPhase is
        // untouched, still `clozeTest`), then tapped "Selanjutnya" again
        // on the revisited Reading screen.
        await controller().advanceToClozeTest();

        // The underlying Firestore write is NOT attempted a second time...
        expect(fakeSessionService.advancePhaseCalls, hasLength(1));
        // ...no error is surfaced (this isn't a failure)...
        expect(state().advanceToClozeError, isNull);
        // ...and the phase is (still) correctly clozeTest, so the caller's
        // existing "error == null -> navigate" check takes the student
        // straight to ClozeTestScreen.
        expect(state().currentPhase, LearningSessionPhase.clozeTest);
      },
    );
  });

  group('cloze test flow', () {
    Future<void> startAndGenerate() async {
      controller().startFlow(
        studentId: 'student-1',
        wordIds: ['run', 'souvenir'],
        sourceType: LearningSessionSourceType.targetGuru,
      );
      fakeAi.generateStoryHandler = (words, prompt) => GenerateStoryResult(
        story: 'I [[run|ran]] and bought a [[souvenir|souvenir]].',
        translation: 'T',
      );
      await controller().generateStory(prompt: 'judul');
      await controller().advanceToClozeTest();
    }

    test('submitCloze only reveals grading locally — no Firestore write yet', () async {
      await startAndGenerate();
      controller().submitCloze();

      expect(state().hasSubmittedCloze, isTrue);
      expect(fakeSessionService.recordClozeResultCalls, isEmpty);
      expect(fakeProgressService.recordClozeCompletionCalls, isEmpty);
    });

    test(
      'confirmClozeAndAdvance grades from the CURRENT answers, writes the session '
      'and immediately writes learningProgress (Decision 3)',
      () async {
        await startAndGenerate();
        controller().setClozeAnswer('run', 'run');
        controller().setClozeAnswer('souvenir', 'run'); // wrong on purpose
        controller().submitCloze();

        final segments = buildClozeSegments(state().storyContent!);
        await controller().confirmClozeAndAdvance(segments);

        expect(fakeSessionService.recordClozeResultCalls, hasLength(1));
        expect(fakeSessionService.recordClozeResultCalls.single['sessionId'], 'session-1');
        expect(fakeSessionService.recordClozeResultCalls.single['clozeTestResult'], {
          'run': true,
          'souvenir': false,
        });

        expect(fakeProgressService.recordClozeCompletionCalls, hasLength(1));
        final progressCall = fakeProgressService.recordClozeCompletionCalls.single;
        expect(progressCall['studentId'], 'student-1');
        expect(progressCall['wordIds'], ['run', 'souvenir']);
        expect(progressCall['sessionId'], 'session-1');

        expect(state().clozeTestResult, {'run': true, 'souvenir': false});
        expect(state().currentPhase, LearningSessionPhase.coWrite);
      },
    );

    test(
      'Stage 3: a failed recordClozeCompletion sets clozeSubmitError and does NOT '
      'advance the phase — the session write already succeeded but this must not '
      'be silently treated as success',
      () async {
        await startAndGenerate();
        controller().setClozeAnswer('run', 'run');
        controller().setClozeAnswer('souvenir', 'souvenir');
        controller().submitCloze();
        fakeProgressService.throwOnRecordClozeCompletion = true;

        final segments = buildClozeSegments(state().storyContent!);
        await controller().confirmClozeAndAdvance(segments);

        expect(fakeSessionService.recordClozeResultCalls, hasLength(1)); // this DID succeed
        expect(state().clozeSubmitError, 'Gagal menyimpan hasil Cloze Test. Coba lagi.');
        expect(state().clozeTestResult, isNull);
        expect(state().currentPhase, LearningSessionPhase.clozeTest); // never advanced
      },
    );
  });

  group('co-write flow', () {
    Future<void> startThroughCloze() async {
      controller().startFlow(
        studentId: 'student-1',
        wordIds: ['run', 'souvenir'],
        sourceType: LearningSessionSourceType.targetGuru,
      );
      fakeAi.generateStoryHandler = (words, prompt) => GenerateStoryResult(
        story: 'I [[run|ran]] and bought a [[souvenir|souvenir]].',
        translation: 'T',
      );
      await controller().generateStory(prompt: 'judul');
      await controller().advanceToClozeTest();
      controller().setClozeAnswer('run', 'run');
      controller().setClozeAnswer('souvenir', 'souvenir');
      controller().submitCloze();
      final segments = buildClozeSegments(state().storyContent!);
      await controller().confirmClozeAndAdvance(segments);
    }

    test(
      'sendTurn (no suggestion) counts the used word as BOTH used and independent',
      () async {
        await startThroughCloze();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
          expect(requestSuggestion, isFalse);
          expect(remainingWords, containsAll(['run', 'souvenir']));
          return const CowriteTurnResult(
            aiTurn: 'Great, what happened next?',
            feedback: 'Well written!',
            hasError: false,
            wordsUsedCorrectly: ['run'],
            suggestion: null,
            aiUsedWords: [],
          );
        };

        await controller().sendTurn('I ran to the store.');

        expect(state().allWordsUsedCorrectly, {'run'});
        expect(state().independentWordsUsedCorrectly, {'run'});
        expect(state().cowriteTranscript, hasLength(2));
        expect(state().cowriteTranscript[0].sender, CowriteSender.siswa);
        expect(state().cowriteTranscript[0].feedback, 'Well written!');
        expect(state().cowriteTranscript[0].usedSuggestion, isFalse);
        expect(state().cowriteTranscript[1].sender, CowriteSender.ai);
        expect(state().isSendingTurn, isFalse);
        expect(state().turnError, isNull);

        expect(fakeSessionService.saveCowriteTranscriptCalls, hasLength(1));
        expect(
          fakeSessionService.saveCowriteTranscriptCalls.single['transcript'],
          state().cowriteTranscript,
        );
      },
    );

    test(
      'requestSuggestion does not touch the transcript, and disqualifies the NEXT '
      'sent turn from independent use (DATA_MODEL.md §10.2 "mandiri")',
      () async {
        await startThroughCloze();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
          expect(requestSuggestion, isTrue);
          return const CowriteTurnResult(
            aiTurn: 'ignored',
            feedback: 'ignored',
            hasError: false,
            wordsUsedCorrectly: ['run'],
            suggestion: 'Try: I ran to buy a souvenir.',
            aiUsedWords: [],
          );
        };

        await controller().requestSuggestion();

        expect(state().pendingSuggestion, 'Try: I ran to buy a souvenir.');
        expect(state().usedSuggestionThisTurn, isTrue);
        expect(state().cowriteTranscript, isEmpty);
        expect(state().allWordsUsedCorrectly, isEmpty);

        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
          expect(requestSuggestion, isFalse);
          return const CowriteTurnResult(
            aiTurn: 'Nice!',
            feedback: null,
            hasError: false,
            wordsUsedCorrectly: ['run'],
            suggestion: null,
            aiUsedWords: [],
          );
        };
        await controller().sendTurn('I ran to buy a souvenir.');

        // Used (for the stop condition/pill display)...
        expect(state().allWordsUsedCorrectly, {'run'});
        // ...but NOT independently, because a suggestion was used this turn.
        expect(state().independentWordsUsedCorrectly, isEmpty);
        expect(state().cowriteTranscript.first.usedSuggestion, isTrue);
        // The flag resets after sending, and the suggestion is cleared.
        expect(state().usedSuggestionThisTurn, isFalse);
        expect(state().pendingSuggestion, isNull);
      },
    );

    test('sending blank/whitespace-only text is a no-op', () async {
      await startThroughCloze();
      fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
        fail('the Worker should never be called for blank input');
      };

      await controller().sendTurn('   ');

      expect(state().cowriteTranscript, isEmpty);
    });

    test('a failed sendTurn sets a friendly error and does not append anything', () async {
      await startThroughCloze();
      fakeAi.cowriteTurnHandler = null; // -> throws

      await controller().sendTurn('I ran fast.');

      expect(state().cowriteTranscript, isEmpty);
      expect(state().turnError, isNotNull);
      expect(state().isSendingTurn, isFalse);
    });

    test(
      'completeCowrite writes the session and the mastery upgrade using the '
      'independent-only word set',
      () async {
        await startThroughCloze();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
          return CowriteTurnResult(
            aiTurn: 'Nice!',
            feedback: null,
            hasError: false,
            wordsUsedCorrectly: [...remainingWords],
            suggestion: null,
            aiUsedWords: const [],
          );
        };
        await controller().sendTurn('I ran and bought a souvenir.');
        expect(state().allWordsUsed, isTrue);

        await controller().completeCowrite();

        expect(fakeSessionService.completeSessionCalls, hasLength(1));
        final sessionCall = fakeSessionService.completeSessionCalls.single;
        expect(sessionCall['sessionId'], 'session-1');
        expect(
          (sessionCall['cowriteWordsUsedCorrectly'] as List<String>).toSet(),
          {'run', 'souvenir'},
        );

        expect(fakeProgressService.recordCowriteCompletionCalls, hasLength(1));
        final progressCall = fakeProgressService.recordCowriteCompletionCalls.single;
        expect(progressCall['studentId'], 'student-1');
        expect(progressCall['sessionId'], 'session-1');
        expect(progressCall['clozeTestResult'], {'run': true, 'souvenir': true});
        expect(
          (progressCall['cowriteWordsUsedCorrectly'] as List<String>).toSet(),
          {'run', 'souvenir'},
        );

        expect(state().currentPhase, LearningSessionPhase.selesai);
      },
    );

    test(
      'Stage 3: a failed recordCowriteCompletion sets turnError and does NOT advance '
      'to selesai — reproduces the exact reported permission-denied bug, where '
      'completeSession() (learningSessions) already succeeded',
      () async {
        await startThroughCloze();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
          return CowriteTurnResult(
            aiTurn: 'Nice!',
            feedback: null,
            hasError: false,
            wordsUsedCorrectly: [...remainingWords],
            suggestion: null,
            aiUsedWords: const [],
          );
        };
        await controller().sendTurn('I ran and bought a souvenir.');
        expect(state().allWordsUsed, isTrue);
        fakeProgressService.throwOnRecordCowriteCompletion = true;

        await controller().completeCowrite();

        expect(fakeSessionService.completeSessionCalls, hasLength(1)); // this DID succeed
        expect(fakeProgressService.recordCowriteCompletionCalls, isEmpty);
        expect(state().turnError, 'Gagal menyelesaikan sesi. Coba lagi.');
        expect(state().currentPhase, LearningSessionPhase.coWrite); // never advanced
      },
    );

    group('Stage 8: aiUsedWords (3-turn fallback) and immediate completion', () {
      test(
        'aiUsedWords is added to allWordsUsedCorrectly but NEVER to '
        'independentWordsUsedCorrectly — AI-assisted usage cannot create mastery credit',
        () async {
          await startThroughCloze();
          var callCount = 0;
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            callCount++;
            return const CowriteTurnResult(
              aiTurn: 'My baby cousin was there too.',
              feedback: 'Bagus, terus lanjutkan!',
              hasError: false,
              wordsUsedCorrectly: ['run'], // the student's own usage
              suggestion: null,
              aiUsedWords: ['souvenir'], // the AI's fallback usage
            );
          };

          await controller().sendTurn('I ran to the store.');

          expect(callCount, 1); // exactly one Worker call for this send
          // Both words are now "used" (drives the pill display/stop condition)...
          expect(state().allWordsUsedCorrectly, {'run', 'souvenir'});
          // ...but only the student's own word counts toward independent/
          // mastery-eligible use — the AI's fallback word never does.
          expect(state().independentWordsUsedCorrectly, {'run'});
        },
      );

      test(
        'Issue 4: the student\'s turn completing the FINAL remaining target ends the '
        'transcript on the student\'s own bubble — no trailing AI bubble is appended',
        () async {
          await startThroughCloze();
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            return CowriteTurnResult(
              aiTurn: 'This reply must not appear.',
              feedback: null,
              hasError: false,
              wordsUsedCorrectly: [...remainingWords], // completes everything
              suggestion: null,
              aiUsedWords: const [],
            );
          };

          await controller().sendTurn('I ran and bought a souvenir.');

          expect(state().allWordsUsed, isTrue);
          expect(state().cowriteTranscript, hasLength(1));
          expect(state().cowriteTranscript.single.sender, CowriteSender.siswa);
          expect(state().cowriteTranscript.single.text, 'I ran and bought a souvenir.');
        },
      );

      test(
        'Issue 4: AI fallback completing the FINAL remaining target keeps the AI '
        'bubble — that bubble is the turn that actually consumed the target',
        () async {
          await startThroughCloze();
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            return CowriteTurnResult(
              aiTurn: 'My souvenir collection grew a little.',
              feedback: 'Bagus!',
              hasError: false,
              wordsUsedCorrectly: const ['run'], // student used only "run" this turn
              suggestion: null,
              aiUsedWords: const ['souvenir'], // AI fallback completes the rest
            );
          };

          await controller().sendTurn('I ran to the store.');

          expect(state().allWordsUsed, isTrue);
          expect(state().cowriteTranscript, hasLength(2));
          expect(state().cowriteTranscript[0].sender, CowriteSender.siswa);
          expect(state().cowriteTranscript[1].sender, CowriteSender.ai);
          expect(
            state().cowriteTranscript[1].text,
            'My souvenir collection grew a little.',
          );
          // Still never counts toward mastery.
          expect(state().independentWordsUsedCorrectly, {'run'});
        },
      );

      test(
        'not complete yet: both the student and AI bubbles are appended, exactly '
        'as before Stage 8 (regression guard)',
        () async {
          await startThroughCloze();
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            return const CowriteTurnResult(
              aiTurn: 'What happened next?',
              feedback: null,
              hasError: false,
              wordsUsedCorrectly: ['run'], // "souvenir" still remains
              suggestion: null,
              aiUsedWords: [],
            );
          };

          await controller().sendTurn('I ran to the store.');

          expect(state().allWordsUsed, isFalse);
          expect(state().cowriteTranscript, hasLength(2));
          expect(state().cowriteTranscript[1].sender, CowriteSender.ai);
        },
      );
    });

    group('bare single-word safety guard (Stage 8 follow-up)', () {
      test(
        'a bare word the Worker incorrectly marks as used is NOT counted, but the '
        'message and feedback are still preserved',
        () async {
          await startThroughCloze();
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            return const CowriteTurnResult(
              aiTurn: 'Tell me more!',
              feedback:
                  "Bagus! Kamu menyebutkan 'breakfast', tapi cobalah untuk membuat "
                  'kalimat lengkap yang lebih panjang.',
              hasError: false,
              wordsUsedCorrectly: ['run'], // note: NOT 'breakfast' — see below
              suggestion: null,
              aiUsedWords: [],
            );
          };

          await controller().sendTurn('breakfast');

          // The bare word must not be counted, even though it isn't one of
          // the two session target words here — this test's real target
          // is proving the message/feedback are preserved regardless of
          // the guard. The next test below reproduces the exact reported
          // shape (Worker wrongly including the bare word itself).
          expect(state().cowriteTranscript, hasLength(2));
          expect(state().cowriteTranscript[0].sender, CowriteSender.siswa);
          expect(state().cowriteTranscript[0].text, 'breakfast');
          expect(
            state().cowriteTranscript[0].feedback,
            "Bagus! Kamu menyebutkan 'breakfast', tapi cobalah untuk membuat "
            'kalimat lengkap yang lebih panjang.',
          );
        },
      );

      test(
        'reproduces the exact live bug: Worker returns the bare word itself in '
        'wordsUsedCorrectly — it must NOT enter allWordsUsedCorrectly or '
        'independentWordsUsedCorrectly',
        () async {
          controller().startFlow(
            studentId: 'student-1',
            wordIds: ['breakfast'],
            sourceType: LearningSessionSourceType.targetGuru,
          );
          fakeAi.generateStoryHandler = (words, prompt) => GenerateStoryResult(
            story: 'I made [[breakfast|breakfast]] this morning.',
            translation: 'T',
          );
          await controller().generateStory(prompt: 'judul');
          await controller().advanceToClozeTest();
          controller().setClozeAnswer('breakfast', 'breakfast');
          controller().submitCloze();
          final segments = buildClozeSegments(state().storyContent!);
          await controller().confirmClozeAndAdvance(segments);

          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            return const CowriteTurnResult(
              aiTurn: 'What did you have with it?',
              feedback:
                  "Bagus! Kamu menyebutkan 'breakfast', tapi cobalah untuk membuat "
                  'kalimat lengkap yang lebih panjang.',
              hasError: false,
              wordsUsedCorrectly: ['breakfast'], // the exact reported bug
              suggestion: null,
              aiUsedWords: [],
            );
          };

          await controller().sendTurn('breakfast');

          expect(state().allWordsUsedCorrectly, isNot(contains('breakfast')));
          expect(state().independentWordsUsedCorrectly, isNot(contains('breakfast')));
          expect(state().allWordsUsed, isFalse);
          // The message and feedback are still there.
          expect(state().cowriteTranscript.first.text, 'breakfast');
          expect(
            state().cowriteTranscript.first.feedback,
            "Bagus! Kamu menyebutkan 'breakfast', tapi cobalah untuk membuat "
            'kalimat lengkap yang lebih panjang.',
          );
        },
      );

      test(
        'a genuine short sentence containing the target word is still counted '
        'normally — the guard is not overly aggressive',
        () async {
          controller().startFlow(
            studentId: 'student-1',
            wordIds: ['breakfast'],
            sourceType: LearningSessionSourceType.targetGuru,
          );
          fakeAi.generateStoryHandler = (words, prompt) => GenerateStoryResult(
            story: 'I made [[breakfast|breakfast]] this morning.',
            translation: 'T',
          );
          await controller().generateStory(prompt: 'judul');
          await controller().advanceToClozeTest();
          controller().setClozeAnswer('breakfast', 'breakfast');
          controller().submitCloze();
          final segments = buildClozeSegments(state().storyContent!);
          await controller().confirmClozeAndAdvance(segments);

          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            return const CowriteTurnResult(
              aiTurn: 'Sounds delicious!',
              feedback: 'Kalimat yang bagus!',
              hasError: false,
              wordsUsedCorrectly: ['breakfast'],
              suggestion: null,
              aiUsedWords: [],
            );
          };

          await controller().sendTurn('I eat breakfast.');

          expect(state().allWordsUsedCorrectly, contains('breakfast'));
          expect(state().independentWordsUsedCorrectly, contains('breakfast'));
          expect(state().allWordsUsed, isTrue);
        },
      );
    });
  });
}
