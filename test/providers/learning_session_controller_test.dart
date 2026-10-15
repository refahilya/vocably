import 'dart:async';
import 'dart:math';

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
import 'package:vocably/utils/cowrite_feedback.dart';

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

  /// `FutureOr` so a test can return an un-completed `Future` (Completer)
  /// to hold a Worker round-trip in flight.
  FutureOr<CowriteTurnResult> Function(
    List<Map<String, String>> transcript,
    List<String> remainingWords,
    bool requestSuggestion,
  )?
  cowriteTurnHandler;

  /// Forced-word (application-selected fallback) turns. `null` -> throws,
  /// like an unreachable Worker.
  FutureOr<CowriteTurnResult> Function(
    List<Map<String, String>> transcript,
    List<String> remainingWords,
    String forcedWord,
  )?
  forcedTurnHandler;

  int cowriteTurnCalls = 0;
  final forcedTurnCalls = <Map<String, dynamic>>[];

  @override
  Future<CowriteTurnResult> cowriteForcedTurn({
    required List<Map<String, String>> transcript,
    required List<String> remainingWords,
    required String forcedWord,
  }) async {
    forcedTurnCalls.add({
      'transcript': transcript,
      'remainingWords': remainingWords,
      'forcedWord': forcedWord,
    });
    final handler = forcedTurnHandler;
    if (handler == null) {
      throw const AiWorkerException('no forced handler configured');
    }
    return await handler(transcript, remainingWords, forcedWord);
  }

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

  /// The `studentTurnContainsIndonesian` flag of every ordinary call, in order.
  final languageFlags = <bool>[];

  @override
  Future<CowriteTurnResult> cowriteTurn({
    required List<Map<String, String>> transcript,
    required List<String> remainingWords,
    required bool requestSuggestion,
    bool studentTurnContainsIndonesian = false,
  }) async {
    cowriteTurnCalls++;
    if (!requestSuggestion) languageFlags.add(studentTurnContainsIndonesian);
    final handler = cowriteTurnHandler;
    if (handler == null) {
      throw const AiWorkerException('no handler configured');
    }
    return await handler(transcript, remainingWords, requestSuggestion);
  }
}

/// Deterministic [Random] for the fallback word pick: returns the queued
/// indices in order (modulo `max`), then 0.
class _ScriptedRandom implements Random {
  _ScriptedRandom([List<int> indices = const []]) : _indices = [...indices];

  final List<int> _indices;
  final requestedMax = <int>[];

  @override
  int nextInt(int max) {
    requestedMax.add(max);
    return _indices.isEmpty ? 0 : _indices.removeAt(0) % max;
  }

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

/// An ordinary-turn Worker reply that credits [wordsUsedCorrectly].
CowriteTurnResult _ordinary({
  String aiTurn = 'Suddenly, the lights went out.',
  List<String> wordsUsedCorrectly = const [],
  String? feedback = 'Kalimatmu sudah benar.',
  String? assessedStudentTurn,
  bool hasError = false,
}) {
  return CowriteTurnResult(
    aiTurn: aiTurn,
    feedback: feedback,
    hasError: hasError,
    wordsUsedCorrectly: wordsUsedCorrectly,
    suggestion: null,
    aiUsedWords: const [],
    assessedStudentTurn: assessedStudentTurn,
  );
}

/// A forced-word Worker reply.
CowriteTurnResult _forced(String aiTurn, {List<String> aiUsedWords = const []}) {
  return CowriteTurnResult(
    aiTurn: aiTurn,
    feedback: null,
    hasError: false,
    wordsUsedCorrectly: const [],
    suggestion: null,
    aiUsedWords: aiUsedWords,
  );
}

void main() {
  late _FakeAiWorkerService fakeAi;
  late _FakeLearningSessionService fakeSessionService;
  late _FakeLearningProgressService fakeProgressService;
  late _ScriptedRandom scriptedRandom;
  late ProviderContainer container;

  setUp(() {
    fakeAi = _FakeAiWorkerService();
    fakeSessionService = _FakeLearningSessionService();
    fakeProgressService = _FakeLearningProgressService();
    scriptedRandom = _ScriptedRandom();
    container = ProviderContainer(
      overrides: [
        aiWorkerServiceProvider.overrideWithValue(fakeAi),
        learningSessionServiceProvider.overrideWithValue(fakeSessionService),
        learningProgressServiceProvider.overrideWithValue(fakeProgressService),
        cowriteFallbackRandomProvider.overrideWithValue(scriptedRandom),
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

        // Stored as the bare English sentence (an English instruction
        // prefix from an older Worker is stripped); the screen adds the
        // Indonesian "Coba tulis" wrapper.
        expect(state().pendingSuggestion, 'I ran to buy a souvenir.');
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

    group('Co-Write Phase 2: application-owned fallback state machine', () {
      /// Starts a flow for [words] and advances it to Fase 3.
      Future<void> startCowriteWith(List<String> words) async {
        controller().startFlow(
          studentId: 'student-1',
          wordIds: words,
          sourceType: LearningSessionSourceType.targetGuru,
        );
        fakeAi.generateStoryHandler = (targetWords, prompt) => GenerateStoryResult(
          story: targetWords.map((w) => 'One [[$w|$w]] here.').join(' '),
          translation: 'T',
        );
        await controller().generateStory(prompt: 'judul');
        await controller().advanceToClozeTest();
        for (final w in words) {
          controller().setClozeAnswer(w, w);
        }
        controller().submitCloze();
        await controller().confirmClozeAndAdvance(buildClozeSegments(state().storyContent!));
      }

      const missText = 'We walked home slowly.';

      void studentAlwaysMisses() {
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
            _ordinary(aiTurn: 'A cat jumped onto the fence.');
      }

      test(
        "Issue 4: the student's turn completing the FINAL remaining target ends the "
        'transcript on the student\'s own bubble — no trailing AI bubble',
        () async {
          await startThroughCloze();
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
              _ordinary(aiTurn: 'This reply must not appear.', wordsUsedCorrectly: [...remainingWords]);

          await controller().sendTurn('I ran and bought a souvenir.');

          expect(state().allWordsUsed, isTrue);
          expect(state().cowriteTranscript, hasLength(1));
          expect(state().cowriteTranscript.single.sender, CowriteSender.siswa);
          expect(fakeAi.forcedTurnCalls, isEmpty);
        },
      );

      test('not complete yet: both the student and the ordinary AI bubble are appended', () async {
        await startThroughCloze();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
            _ordinary(aiTurn: 'What happened next?', wordsUsedCorrectly: const ['run']);

        await controller().sendTurn('I ran to the store.');

        expect(state().allWordsUsed, isFalse);
        expect(state().cowriteTranscript, hasLength(2));
        expect(state().cowriteTranscript[1].sender, CowriteSender.ai);
        expect(state().consecutiveMissedStudentTurns, 0);
      });

      test('"Okay." is accepted as an ordinary turn (Worker called) and counts as a miss', () async {
        await startThroughCloze();
        studentAlwaysMisses();

        await controller().sendTurn('Okay.');

        expect(fakeAi.cowriteTurnCalls, 1);
        expect(state().turnError, isNull);
        expect(state().cowriteTranscript, hasLength(2));
        expect(state().consecutiveMissedStudentTurns, 1);
      });

      test(
        'exactly three consecutive missed student turns trigger ONE forced turn with '
        'exactly one randomly selected remaining word; the validated word becomes '
        'session-used but never independent',
        () async {
          await startCowriteWith(['attack', 'button', 'ability']);
          studentAlwaysMisses();
          scriptedRandom._indices.add(1); // -> 'button'
          fakeAi.forcedTurnHandler = (transcript, remainingWords, forcedWord) =>
              _forced('Behind the curtain, the guard pressed a hidden $forcedWord.');

          await controller().sendTurn(missText);
          await controller().sendTurn(missText);
          expect(state().consecutiveMissedStudentTurns, 2);
          expect(fakeAi.forcedTurnCalls, isEmpty);

          await controller().sendTurn(missText);

          expect(fakeAi.forcedTurnCalls, hasLength(1));
          final call = fakeAi.forcedTurnCalls.single;
          expect(call['forcedWord'], 'button');
          expect(call['remainingWords'], ['attack', 'button', 'ability']);
          expect(scriptedRandom.requestedMax, [3]);
          // The forced request is built from the transcript ending with the
          // latest student message — never with the discarded ordinary turn.
          final sentTranscript = call['transcript'] as List<Map<String, String>>;
          expect(sentTranscript.last, {'sender': 'siswa', 'text': missText});

          expect(state().allWordsUsedCorrectly, {'button'});
          expect(state().independentWordsUsedCorrectly, isEmpty);
          expect(state().consecutiveMissedStudentTurns, 0);
          expect(
            state().cowriteTranscript.last.text,
            'Behind the curtain, the guard pressed a hidden button.',
          );
          expect(state().cowriteTranscript, hasLength(6));
        },
      );

      test('the counter resets after valid student usage', () async {
        await startCowriteWith(['attack', 'button', 'ability']);
        fakeAi.forcedTurnHandler = (transcript, remainingWords, forcedWord) =>
            _forced('Everyone talked about the $forcedWord.');
        studentAlwaysMisses();

        await controller().sendTurn(missText);
        await controller().sendTurn(missText);
        expect(state().consecutiveMissedStudentTurns, 2);

        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
            _ordinary(wordsUsedCorrectly: const ['attack']);
        await controller().sendTurn('The dragon decided to attack the castle.');
        expect(state().consecutiveMissedStudentTurns, 0);
        expect(state().independentWordsUsedCorrectly, {'attack'});

        studentAlwaysMisses();
        await controller().sendTurn(missText);
        await controller().sendTurn(missText);
        expect(state().consecutiveMissedStudentTurns, 2);
        expect(fakeAi.forcedTurnCalls, isEmpty);

        await controller().sendTurn(missText);
        expect(fakeAi.forcedTurnCalls, hasLength(1));
        expect(fakeAi.forcedTurnCalls.single['remainingWords'], ['button', 'ability']);
      });

      test(
        'AI turns never change the counter — even an ordinary AI turn that contains '
        'target words neither credits them nor resets the count',
        () async {
          await startCowriteWith(['attack', 'button']);
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
              _ordinary(aiTurn: 'The knight pressed a button to attack.');

          await controller().sendTurn(missText);
          await controller().sendTurn(missText);

          expect(state().cowriteTranscript, hasLength(4)); // 2 student + 2 AI
          expect(state().consecutiveMissedStudentTurns, 2);
          expect(state().allWordsUsedCorrectly, isEmpty);
        },
      );

      test('locally rejected inputs and failed sends do not change the counter', () async {
        await startCowriteWith(['attack', 'button']);
        studentAlwaysMisses();

        await controller().sendTurn(missText);
        expect(state().consecutiveMissedStudentTurns, 1);

        await controller().sendTurn('attack'); // rejected locally
        expect(state().turnError, kBareOrFragmentTurnErrorMessage);
        expect(state().consecutiveMissedStudentTurns, 1);

        fakeAi.cowriteTurnHandler = null; // Worker failure
        await controller().sendTurn(missText);
        expect(state().turnError, 'Gagal mengirim giliran. Coba lagi.');
        expect(state().consecutiveMissedStudentTurns, 1);

        studentAlwaysMisses();
        await controller().sendTurn(missText);
        expect(state().consecutiveMissedStudentTurns, 2);
        expect(fakeAi.forcedTurnCalls, isEmpty);
      });

      test(
        'a forced turn whose text does not contain the selected word does not mark it '
        '(the aiUsedWords claim is ignored); the ordinary turn is shown and the next '
        'missed turn retries the fallback',
        () async {
          await startCowriteWith(['attack', 'button']);
          studentAlwaysMisses();
          fakeAi.forcedTurnHandler = (transcript, remainingWords, forcedWord) =>
              _forced('The wind howled outside.', aiUsedWords: [forcedWord]);

          for (var i = 0; i < 3; i++) {
            await controller().sendTurn(missText);
          }

          expect(fakeAi.forcedTurnCalls, hasLength(1));
          expect(state().allWordsUsedCorrectly, isEmpty);
          expect(state().cowriteTranscript.last.text, 'A cat jumped onto the fence.');
          expect(state().consecutiveMissedStudentTurns, 3);

          fakeAi.forcedTurnHandler = (transcript, remainingWords, forcedWord) =>
              _forced('Suddenly the soldiers began to $forcedWord.');
          await controller().sendTurn(missText);

          expect(fakeAi.forcedTurnCalls, hasLength(2));
          expect(state().allWordsUsedCorrectly, {'attack'});
          expect(state().consecutiveMissedStudentTurns, 0);
        },
      );

      test('a failed forced-turn call marks nothing and keeps the ordinary AI turn', () async {
        await startCowriteWith(['attack', 'button']);
        studentAlwaysMisses();
        fakeAi.forcedTurnHandler = null; // Worker 502 / network failure

        for (var i = 0; i < 3; i++) {
          await controller().sendTurn(missText);
        }

        expect(fakeAi.forcedTurnCalls, hasLength(1));
        expect(state().turnError, isNull);
        expect(state().allWordsUsedCorrectly, isEmpty);
        expect(state().cowriteTranscript, hasLength(6));
        expect(state().cowriteTranscript.last.text, 'A cat jumped onto the fence.');
        expect(state().consecutiveMissedStudentTurns, 3);
      });

      test(
        'repeated fallback cycles cover every remaining word one at a time until the '
        'session closes; bot usage is never persisted as student mastery',
        () async {
          await startCowriteWith(['attack', 'button', 'ability']);
          studentAlwaysMisses();
          fakeAi.forcedTurnHandler = (transcript, remainingWords, forcedWord) =>
              _forced('Everyone talked about the $forcedWord.');

          var turns = 0;
          while (!state().allWordsUsed && turns < 20) {
            await controller().sendTurn(missText);
            turns++;
          }

          expect(turns, 9); // three cycles of three missed turns
          expect(state().allWordsUsed, isTrue);
          final forcedWords = [
            for (final c in fakeAi.forcedTurnCalls) c['forcedWord'] as String,
          ];
          expect(forcedWords, ['attack', 'button', 'ability']); // one per cycle
          expect(
            [for (final c in fakeAi.forcedTurnCalls) (c['remainingWords'] as List).length],
            [3, 2, 1],
          );
          expect(state().independentWordsUsedCorrectly, isEmpty);
          // The completing bot bubble is kept (it consumed the last word).
          expect(state().cowriteTranscript.last.sender, CowriteSender.ai);

          // A further send after completion is ignored.
          await controller().sendTurn(missText);
          expect(fakeAi.cowriteTurnCalls, 9);

          await controller().completeCowrite();
          expect(
            fakeSessionService.completeSessionCalls.single['cowriteWordsUsedCorrectly'],
            isEmpty,
          );
          expect(
            fakeProgressService.recordCowriteCompletionCalls.single['cowriteWordsUsedCorrectly'],
            isEmpty,
          );
          expect(state().currentPhase, LearningSessionPhase.selesai);
        },
      );

      test(
        'mixed session: only the student\'s own word is persisted as independent '
        '(mastery) usage; the fallback word only completes the session',
        () async {
          await startCowriteWith(['attack', 'button']);
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
              _ordinary(wordsUsedCorrectly: const ['attack']);
          await controller().sendTurn('The dragon decided to attack the castle.');

          studentAlwaysMisses();
          fakeAi.forcedTurnHandler = (transcript, remainingWords, forcedWord) =>
              _forced('A soldier pressed the red $forcedWord.');
          for (var i = 0; i < 3; i++) {
            await controller().sendTurn(missText);
          }

          expect(state().allWordsUsedCorrectly, {'attack', 'button'});
          expect(state().independentWordsUsedCorrectly, {'attack'});
          expect(state().allWordsUsed, isTrue);

          await controller().completeCowrite();

          expect(
            fakeSessionService.completeSessionCalls.single['cowriteWordsUsedCorrectly'],
            ['attack'],
          );
          expect(
            fakeProgressService.recordCowriteCompletionCalls.single['cowriteWordsUsedCorrectly'],
            ['attack'],
          );
        },
      );

      test('a double tap on "Selesai" writes the completion only once', () async {
        await startThroughCloze();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
            _ordinary(wordsUsedCorrectly: [...remainingWords]);
        await controller().sendTurn('I ran and bought a souvenir.');

        final first = controller().completeCowrite();
        final second = controller().completeCowrite();
        await Future.wait([first, second]);

        expect(fakeSessionService.completeSessionCalls, hasLength(1));
        expect(fakeProgressService.recordCowriteCompletionCalls, hasLength(1));
        expect(state().isCompletingCowrite, isFalse);
        expect(state().currentPhase, LearningSessionPhase.selesai);
      });

      test(
        'CW-05: a meaningful use with a tense error, reported by the model as a surface '
        'form, is credited at session level AND independently, and resets the counter',
        () async {
          await startCowriteWith(['attack', 'village']);
          studentAlwaysMisses();
          await controller().sendTurn(missText);
          expect(state().consecutiveMissedStudentTurns, 1);

          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) => _ordinary(
                feedback: 'Seharusnya "attacked" karena kejadian lampau.',
                // Surface form + formatting, as a model may return it.
                wordsUsedCorrectly: const ['Attacked.'],
              );
          await controller().sendTurn('Yesterday the monster attack the castle.');

          expect(state().allWordsUsedCorrectly, {'attack'});
          expect(state().independentWordsUsedCorrectly, {'attack'});
          expect(state().consecutiveMissedStudentTurns, 0);
          expect(
            state().cowriteTranscript[2].feedback,
            'Seharusnya "attacked" karena kejadian lampau.',
          );
        },
      );

      test(
        'CW-05: a model-reported target absent from the student text, or an invalid '
        'over-inflection, is not credited and counts as a miss',
        () async {
          await startCowriteWith(['attack', 'village']);
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
              _ordinary(wordsUsedCorrectly: const ['attack', 'village']);

          await controller().sendTurn('The dragon attackked the castle.');

          expect(state().allWordsUsedCorrectly, isEmpty);
          expect(state().independentWordsUsedCorrectly, isEmpty);
          expect(state().consecutiveMissedStudentTurns, 1);
        },
      );

      group('Indonesian / mixed-language input', () {
        test(
          '"aku attack temanku": accepted "attack" counts for session coverage but NOT '
          'independent mastery, the app flag is sent, the counter resets, and the '
          'persisted cowriteWordsUsedCorrectly excludes it',
          () async {
            await startCowriteWith(['attack']);
            fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) => _ordinary(
                  feedback: 'Coba tulis kalimatmu dalam bahasa Inggris, ya.',
                  wordsUsedCorrectly: const ['attack'],
                );

            await controller().sendTurn('aku attack temanku');

            expect(fakeAi.languageFlags, [true]);
            expect(state().allWordsUsedCorrectly, {'attack'});
            expect(state().independentWordsUsedCorrectly, isEmpty);
            expect(state().consecutiveMissedStudentTurns, 0);
            expect(state().allWordsUsed, isTrue);
            expect(
              state().cowriteTranscript.first.feedback,
              'Coba tulis kalimatmu dalam bahasa Inggris, ya.',
            );

            await controller().completeCowrite();

            expect(
              fakeSessionService.completeSessionCalls.single['cowriteWordsUsedCorrectly'],
              isEmpty,
            );
            expect(
              fakeProgressService.recordCowriteCompletionCalls.single['cowriteWordsUsedCorrectly'],
              isEmpty,
            );
          },
        );

        test('Indonesian input without a target word: no credit, counter advances as before', () async {
          await startCowriteWith(['attack', 'village']);
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
              _ordinary(feedback: 'Coba tulis kalimatmu dalam bahasa Inggris, ya.');

          await controller().sendTurn('lalu aku tertawa hahaha');

          expect(fakeAi.languageFlags, [true]);
          expect(state().allWordsUsedCorrectly, isEmpty);
          expect(state().independentWordsUsedCorrectly, isEmpty);
          expect(state().consecutiveMissedStudentTurns, 1);
          expect(state().cowriteTranscript, hasLength(2));
        });

        test('valid English use keeps CW-05 behavior: session coverage AND independent mastery', () async {
          await startCowriteWith(['attack', 'village']);
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
              _ordinary(wordsUsedCorrectly: const ['attacked']);

          await controller().sendTurn('Yesterday the monster attack the castle.');

          expect(fakeAi.languageFlags, [false]);
          expect(state().allWordsUsedCorrectly, {'attack'});
          expect(state().independentWordsUsedCorrectly, {'attack'});
        });

        test('English with name-like or homograph words is not treated as mixed-language', () async {
          await startCowriteWith(['attack', 'village']);
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
              _ordinary(wordsUsedCorrectly: const ['attack']);

          await controller().sendTurn('Dan saw the dragon attack the main gate.');

          expect(fakeAi.languageFlags, [false]);
          expect(state().independentWordsUsedCorrectly, {'attack'});
        });

        test('a suggestion turn combined with mixed-language input gives no independent credit', () async {
          await startCowriteWith(['attack', 'village']);
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
              requestSuggestion
                  ? const CowriteTurnResult(
                      aiTurn: '',
                      feedback: null,
                      hasError: false,
                      wordsUsedCorrectly: [],
                      suggestion: 'The dragon attacked the village.',
                      aiUsedWords: [],
                    )
                  : _ordinary(wordsUsedCorrectly: const ['attack']);

          await controller().requestSuggestion();
          await controller().sendTurn('naga itu attack desa');

          expect(state().allWordsUsedCorrectly, {'attack'});
          expect(state().independentWordsUsedCorrectly, isEmpty);
          expect(state().cowriteTranscript.first.usedSuggestion, isTrue);
        });

        test('bare target words are still rejected locally; mere mentions earn nothing unless reported', () async {
          await startCowriteWith(['attack', 'village']);
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) => _ordinary();

          await controller().sendTurn('attack!');
          expect(state().turnError, kBareOrFragmentTurnErrorMessage);
          expect(fakeAi.cowriteTurnCalls, 0);

          await controller().sendTurn('aku tidak tahu kata attack');
          expect(state().allWordsUsedCorrectly, isEmpty);
          expect(state().independentWordsUsedCorrectly, isEmpty);
        });

        test(
          'three Indonesian misses trigger the unchanged fallback; the bot word counts for '
          'the session only and never as independent mastery',
          () async {
            await startCowriteWith(['attack', 'village']);
            fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
                _ordinary(feedback: 'Coba tulis kalimatmu dalam bahasa Inggris, ya.');
            fakeAi.forcedTurnHandler = (transcript, remainingWords, forcedWord) =>
                _forced('Suddenly the soldiers began to $forcedWord.');

            for (final text in [
              'lalu aku tertawa hahaha',
              'gpt, bantu aku membuat list packing',
              'aku mau pulang',
            ]) {
              await controller().sendTurn(text);
            }

            expect(fakeAi.forcedTurnCalls, hasLength(1));
            expect(fakeAi.forcedTurnCalls.single['forcedWord'], 'attack');
            expect(state().allWordsUsedCorrectly, {'attack'});
            expect(state().independentWordsUsedCorrectly, isEmpty);
            expect(state().consecutiveMissedStudentTurns, 0);
          },
        );
      });
    });

    group('feedback-to-turn association and concurrency', () {
      test('feedback is attached to the exact turn that was sent, after the response arrives', () async {
        await startThroughCloze();
        final pending = Completer<CowriteTurnResult>();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
          expect(transcript.last, {'sender': 'siswa', 'text': 'I ran to the store.'});
          return pending.future;
        };

        final send = controller().sendTurn('I ran to the store.');
        expect(state().cowriteTranscript.single.text, 'I ran to the store.');
        expect(state().cowriteTranscript.single.feedback, isNull);

        // A second send while the first is in flight is ignored.
        await controller().sendTurn('Another sentence about the park.');
        expect(fakeAi.cowriteTurnCalls, 1);

        pending.complete(
          _ordinary(
            feedback: 'Tepat, "ran" adalah bentuk lampau dari "run".',
            wordsUsedCorrectly: const ['run'],
            assessedStudentTurn: 'I ran to the store.',
          ),
        );
        await send;

        expect(state().cowriteTranscript.first.text, 'I ran to the store.');
        expect(
          state().cowriteTranscript.first.feedback,
          'Tepat, "ran" adalah bentuk lampau dari "run".',
        );
      });

      test(
        'a response whose assessedStudentTurn differs from the sent turn is rejected '
        '(rolled back like a failed send) instead of attaching foreign feedback',
        () async {
          await startThroughCloze();
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) => _ordinary(
                feedback: 'Feedback about some other sentence.',
                wordsUsedCorrectly: const ['run'],
                assessedStudentTurn: 'I goes to school.',
              );

          await controller().sendTurn('I ran to the store.');

          expect(state().cowriteTranscript, isEmpty);
          expect(state().allWordsUsedCorrectly, isEmpty);
          expect(state().turnError, 'Gagal mengirim giliran. Coba lagi.');
          expect(state().consecutiveMissedStudentTurns, 0);
        },
      );

      test('a response arriving after the flow was restarted is dropped', () async {
        await startThroughCloze();
        final pending = Completer<CowriteTurnResult>();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
            pending.future;

        final send = controller().sendTurn('I ran to the store.');
        controller().startFlow(
          studentId: 'student-1',
          wordIds: ['ability'],
          sourceType: LearningSessionSourceType.targetGuru,
        );
        pending.complete(_ordinary(wordsUsedCorrectly: const ['run']));
        await send;

        expect(state().wordIds, ['ability']);
        expect(state().cowriteTranscript, isEmpty);
        expect(state().allWordsUsedCorrectly, isEmpty);
        expect(fakeSessionService.saveCowriteTranscriptCalls, isEmpty);
      });

      test('"Saran menulis" is ignored while a turn is being sent, and vice versa', () async {
        await startThroughCloze();
        final pendingTurn = Completer<CowriteTurnResult>();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
          if (requestSuggestion) fail('no suggestion request while sending');
          return pendingTurn.future;
        };
        final send = controller().sendTurn('I ran to the store.');
        await controller().requestSuggestion();
        expect(state().usedSuggestionThisTurn, isFalse);
        pendingTurn.complete(_ordinary(wordsUsedCorrectly: const ['run']));
        await send;

        final pendingSuggestion = Completer<CowriteTurnResult>();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
          if (!requestSuggestion) fail('no turn may be sent while a suggestion is loading');
          return pendingSuggestion.future;
        };
        final suggestion = controller().requestSuggestion();
        await controller().sendTurn('I bought a souvenir.');
        expect(state().cowriteTranscript, hasLength(2));
        pendingSuggestion.complete(
          const CowriteTurnResult(
            aiTurn: '',
            feedback: null,
            hasError: false,
            wordsUsedCorrectly: [],
            suggestion: 'I bought a souvenir at the shop.',
            aiUsedWords: [],
          ),
        );
        await suggestion;
        expect(state().pendingSuggestion, 'I bought a souvenir at the shop.');
      });
    });

    group('CW-02: feedback classification, reconciliation, and turn alignment', () {
      CowriteTurn studentTurn(int index) => state().cowriteTranscript[index];

      test('validated use with no important problem -> positive; credit unchanged', () async {
        await startThroughCloze();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) => _ordinary(
              feedback: 'Tepat, "ran" dipakai untuk kejadian lampau.',
              wordsUsedCorrectly: const ['run'],
            );

        await controller().sendTurn('I ran to the store.');

        expect(studentTurn(0).feedback, 'Tepat, "ran" dipakai untuk kejadian lampau.');
        expect(studentTurn(0).feedbackKind, CowriteFeedbackKind.positive);
        expect(state().allWordsUsedCorrectly, {'run'});
        expect(state().independentWordsUsedCorrectly, {'run'});
        expect(state().cowriteTranscript[1].feedbackKind, isNull); // AI turn
      });

      test(
        'validated use WITH an important problem -> needsImprovement, but the credit '
        '(coverage and independent mastery) is exactly the same as a positive turn',
        () async {
          await startThroughCloze();
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) => _ordinary(
                feedback: '"run" sudah tepat. Seharusnya "ran" karena kejadiannya lampau.',
                wordsUsedCorrectly: const ['run'],
                hasError: true,
              );

          await controller().sendTurn('Yesterday I run to the store.');

          expect(studentTurn(0).feedbackKind, CowriteFeedbackKind.needsImprovement);
          expect(state().allWordsUsedCorrectly, {'run'});
          expect(state().independentWordsUsedCorrectly, {'run'});
          expect(state().consecutiveMissedStudentTurns, 0);
        },
      );

      test('an attempted but uncredited target word -> needsImprovement, no credit', () async {
        await startThroughCloze();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) => _ordinary(
              feedback: 'Kata "souvenir" baru disebut, belum dipakai dalam cerita.',
            );

        await controller().sendTurn('I do not know the word souvenir.');

        expect(studentTurn(0).feedbackKind, CowriteFeedbackKind.needsImprovement);
        expect(state().allWordsUsedCorrectly, isEmpty);
        expect(state().consecutiveMissedStudentTurns, 1);
      });

      test('no target word -> neutral reminder, even when the text sounds positive', () async {
        await startThroughCloze();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) => _ordinary(
              feedback: 'Kalimat yang bagus sekali!',
            );

        await controller().sendTurn('We walked home slowly.');

        expect(studentTurn(0).feedbackKind, CowriteFeedbackKind.reminder);
        expect(state().allWordsUsedCorrectly, isEmpty);
      });

      test('Indonesian/mixed input -> neutral reminder; credit stays session-only', () async {
        await startThroughCloze();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) => _ordinary(
              feedback: 'Coba tulis kalimatmu dalam bahasa Inggris, ya.',
              wordsUsedCorrectly: const ['souvenir'],
              hasError: true,
            );

        await controller().sendTurn('aku beli souvenir di pasar');

        expect(studentTurn(0).feedback, 'Coba tulis kalimatmu dalam bahasa Inggris, ya.');
        expect(studentTurn(0).feedbackKind, CowriteFeedbackKind.reminder);
        expect(state().allWordsUsedCorrectly, {'souvenir'});
        expect(state().independentWordsUsedCorrectly, isEmpty);
      });

      test(
        'a Worker claim that client validation rejects (older Worker) replaces the '
        'praising feedback and is never shown as positive',
        () async {
          await startThroughCloze();
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) => _ordinary(
                feedback: 'Bagus, "souvenir" dipakai dengan tepat!',
                wordsUsedCorrectly: const ['souvenir'],
              );

          await controller().sendTurn('We walked home slowly.');

          expect(studentTurn(0).feedback, kCowriteUncreditedClaimFeedback);
          expect(studentTurn(0).feedbackKind, CowriteFeedbackKind.reminder);
          expect(state().allWordsUsedCorrectly, isEmpty);
        },
      );

      test('null feedback gets no kind', () async {
        await startThroughCloze();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
            _ordinary(feedback: null, wordsUsedCorrectly: const ['run']);

        await controller().sendTurn('I ran to the store.');

        expect(studentTurn(0).feedback, isNull);
        expect(studentTurn(0).feedbackKind, isNull);
      });

      test('the persisted transcript never contains the display-only kind', () async {
        await startThroughCloze();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
            _ordinary(wordsUsedCorrectly: const ['run']);

        await controller().sendTurn('I ran to the store.');

        final saved = fakeSessionService.saveCowriteTranscriptCalls.single['transcript']
            as List<CowriteTurn>;
        expect(saved.first.feedbackKind, CowriteFeedbackKind.positive);
        expect(saved.first.toMap().keys, {'sender', 'text', 'feedback', 'usedSuggestion'});
      });

      test(
        'an ordinary-turn failure (e.g. Worker 502 for an unacceptable continuation) '
        'rolls back only the new turn; the previous turn keeps its own feedback',
        () async {
          await startThroughCloze();
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) => _ordinary(
                feedback: 'Tepat, "ran" dipakai untuk kejadian lampau.',
                wordsUsedCorrectly: const ['run'],
              );
          await controller().sendTurn('I ran to the store.');

          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
              throw const AiWorkerException(
                'AI proxy returned 502: {"error":"AI did not produce an acceptable story continuation."}',
              );
          await controller().sendTurn('We walked home slowly.');

          expect(state().cowriteTranscript, hasLength(2));
          expect(studentTurn(0).feedback, 'Tepat, "ran" dipakai untuk kejadian lampau.');
          expect(studentTurn(0).feedbackKind, CowriteFeedbackKind.positive);
          expect(state().turnError, 'Gagal mengirim giliran. Coba lagi.');
          expect(state().consecutiveMissedStudentTurns, 0);
          expect(state().isSendingTurn, isFalse);
        },
      );

      test(
        'while a slow fallback call is pending, the new turn has no feedback yet and '
        'the previous turn keeps its own; afterwards each turn has its own feedback',
        () async {
          await startThroughCloze();
          var n = 0;
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            n++;
            return _ordinary(
              feedback: 'Coba pakai kata "souvenir" ($n).',
              aiTurn: 'A cat jumped onto fence number $n.',
              assessedStudentTurn: transcript.last['text'],
            );
          };
          await controller().sendTurn('We walked home slowly.');
          await controller().sendTurn('The sky turned dark.');

          final pendingForced = Completer<CowriteTurnResult>();
          fakeAi.forcedTurnHandler = (transcript, remainingWords, forcedWord) =>
              pendingForced.future;
          final send = controller().sendTurn('Everyone went to sleep.');
          await Future<void>.delayed(Duration.zero);

          expect(fakeAi.forcedTurnCalls, hasLength(1));
          final turns = state().cowriteTranscript;
          expect(turns[2].text, 'The sky turned dark.');
          expect(turns[2].feedback, 'Coba pakai kata "souvenir" (2).');
          expect(turns.last.text, 'Everyone went to sleep.');
          expect(turns.last.feedback, isNull);

          pendingForced.complete(_forced('Outside, a girl held a tiny ${fakeAi.forcedTurnCalls.single['forcedWord']}.'));
          await send;

          final after = state().cowriteTranscript;
          expect(after[2].feedback, 'Coba pakai kata "souvenir" (2).');
          expect(after[4].text, 'Everyone went to sleep.');
          expect(after[4].feedback, 'Coba pakai kata "souvenir" (3).');
          expect(after[4].feedbackKind, CowriteFeedbackKind.reminder);
          expect(after.last.sender, CowriteSender.ai);
        },
      );

      test('a fallback response arriving after a restart is dropped with its feedback', () async {
        await startThroughCloze();
        fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) =>
            _ordinary(feedback: 'Coba pakai kata target.');
        await controller().sendTurn('We walked home slowly.');
        await controller().sendTurn('The sky turned dark.');

        final pendingForced = Completer<CowriteTurnResult>();
        fakeAi.forcedTurnHandler = (transcript, remainingWords, forcedWord) =>
            pendingForced.future;
        final send = controller().sendTurn('Everyone went to sleep.');
        await Future<void>.delayed(Duration.zero);
        controller().startFlow(
          studentId: 'student-1',
          wordIds: ['ability'],
          sourceType: LearningSessionSourceType.targetGuru,
        );
        pendingForced.complete(_forced('Outside, a girl held a tiny souvenir.'));
        await send;

        expect(state().wordIds, ['ability']);
        expect(state().cowriteTranscript, isEmpty);
        expect(state().allWordsUsedCorrectly, isEmpty);
      });
    });

    group('Co-Write Phase 1: deterministic target-word validation and bare-input handling', () {
      test(
        '1. Student turn does NOT contain target word, AI returns it in wordsUsedCorrectly -> rejected',
        () async {
          await startThroughCloze();
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            return const CowriteTurnResult(
              aiTurn: 'What did you see there?',
              feedback: 'Kalimat yang bagus!',
              hasError: false,
              wordsUsedCorrectly: ['souvenir'], // hallucinated by AI
              suggestion: null,
              aiUsedWords: [],
            );
          };

          await controller().sendTurn('I went to the park.');

          expect(state().allWordsUsedCorrectly, isEmpty);
          expect(state().independentWordsUsedCorrectly, isEmpty);
          expect(state().allWordsUsed, isFalse);
        },
      );

      test(
        '2. Student turn contains target word in a valid sentence, AI returns it -> accepted',
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

          expect(state().allWordsUsedCorrectly, {'breakfast'});
          expect(state().independentWordsUsedCorrectly, {'breakfast'});
          expect(state().allWordsUsed, isTrue);
        },
      );

      test(
        '3 & 4 & 10. Bare target words ("attack", "button", "breakfast") and bare words '
        'with punctuation ("button?", "button!") are rejected locally without calling the '
        'Worker, entering cowriteTranscript, or triggering a bot continuation',
        () async {
          controller().startFlow(
            studentId: 'student-1',
            wordIds: ['attack', 'button', 'breakfast'],
            sourceType: LearningSessionSourceType.targetGuru,
          );
          fakeAi.generateStoryHandler = (words, prompt) => GenerateStoryResult(
            story:
                'They [[attack|attacked]] the [[button|button]] before [[breakfast|breakfast]].',
            translation: 'T',
          );
          await controller().generateStory(prompt: 'judul');
          await controller().advanceToClozeTest();
          controller().setClozeAnswer('attack', 'attack');
          controller().setClozeAnswer('button', 'button');
          controller().setClozeAnswer('breakfast', 'breakfast');
          controller().submitCloze();
          final segments = buildClozeSegments(state().storyContent!);
          await controller().confirmClozeAndAdvance(segments);

          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            fail('Worker must NOT be called when input is a bare word');
          };

          for (final bareInput in ['attack', 'button', 'breakfast', 'button?', 'button!']) {
            await controller().sendTurn(bareInput);
            expect(state().cowriteTranscript, isEmpty);
            expect(state().allWordsUsedCorrectly, isEmpty);
            expect(state().independentWordsUsedCorrectly, isEmpty);
            expect(state().isSendingTurn, isFalse);
            expect(state().turnError, kBareOrFragmentTurnErrorMessage);
          }
          expect(fakeSessionService.saveCowriteTranscriptCalls, isEmpty);
        },
      );

      test(
        '5 & 6 & 10. Bare target-word lists ("attack button completely"), repeated words '
        '("button button"), and determiner fragments ("the button", "a souvenir") are '
        'rejected locally without calling the Worker or appending to cowriteTranscript',
        () async {
          controller().startFlow(
            studentId: 'student-1',
            wordIds: ['attack', 'button', 'completely'],
            sourceType: LearningSessionSourceType.targetGuru,
          );
          fakeAi.generateStoryHandler = (words, prompt) => GenerateStoryResult(
            story:
                'They [[attack|attacked]] the [[button|button]] [[completely|completely]].',
            translation: 'T',
          );
          await controller().generateStory(prompt: 'judul');
          await controller().advanceToClozeTest();
          controller().setClozeAnswer('attack', 'attack');
          controller().setClozeAnswer('button', 'button');
          controller().setClozeAnswer('completely', 'completely');
          controller().submitCloze();
          final segments = buildClozeSegments(state().storyContent!);
          await controller().confirmClozeAndAdvance(segments);

          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            fail('Worker must NOT be called for bare target-word lists or fragments');
          };

          for (final fragment in [
            'attack button completely',
            'button button',
            'the button',
            'a button',
          ]) {
            await controller().sendTurn(fragment);
            expect(state().cowriteTranscript, isEmpty);
            expect(state().allWordsUsedCorrectly, isEmpty);
            expect(state().independentWordsUsedCorrectly, isEmpty);
            expect(state().isSendingTurn, isFalse);
            expect(state().turnError, kBareOrFragmentTurnErrorMessage);
          }
        },
      );

      test(
        '7. Student turn containing only a substring match (e.g. "attacker" for "attack") '
        'is NOT credited even if AI returns the target word in wordsUsedCorrectly',
        () async {
          controller().startFlow(
            studentId: 'student-1',
            wordIds: ['attack', 'run'],
            sourceType: LearningSessionSourceType.targetGuru,
          );
          fakeAi.generateStoryHandler = (words, prompt) => GenerateStoryResult(
            story: 'They [[attack|attacked]] and [[run|ran]].',
            translation: 'T',
          );
          await controller().generateStory(prompt: 'judul');
          await controller().advanceToClozeTest();
          controller().setClozeAnswer('attack', 'attack');
          controller().setClozeAnswer('run', 'run');
          controller().submitCloze();
          final segments = buildClozeSegments(state().storyContent!);
          await controller().confirmClozeAndAdvance(segments);

          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            return const CowriteTurnResult(
              aiTurn: 'Who was chasing them?',
              feedback: 'Kalimat yang bagus!',
              hasError: false,
              wordsUsedCorrectly: ['attack', 'run'], // 'attack' is a false positive on 'attacker'
              suggestion: null,
              aiUsedWords: [],
            );
          };

          await controller().sendTurn('The attacker ran away.');

          // 'ran' is a valid inflection of 'run', but 'attacker' is NOT 'attack'.
          expect(state().allWordsUsedCorrectly, {'run'});
          expect(state().independentWordsUsedCorrectly, {'run'});
          expect(state().allWordsUsed, isFalse);
        },
      );

      test(
        '8. Bot turn does NOT contain the word in aiUsedWords -> rejected',
        () async {
          await startThroughCloze();
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            return const CowriteTurnResult(
              aiTurn: 'My baby cousin was there too.',
              feedback: 'Bagus!',
              hasError: false,
              wordsUsedCorrectly: ['run'],
              suggestion: null,
              aiUsedWords: ['souvenir'], // absent from aiTurn!
            );
          };

          await controller().sendTurn('I ran to the store.');

          expect(state().allWordsUsedCorrectly, {'run'});
          expect(state().independentWordsUsedCorrectly, {'run'});
          expect(state().allWordsUsed, isFalse);
        },
      );

      test(
        'incidental bot usage in an ORDINARY turn (exact or inflected, with or without '
        'aiUsedWords) never marks the word used — it stays eligible for the student and '
        'for a future application-selected fallback',
        () async {
          await startThroughCloze();
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            return const CowriteTurnResult(
              aiTurn: 'I also bought two souvenirs for my sister.',
              feedback: 'Kalimat yang bagus!',
              hasError: false,
              wordsUsedCorrectly: ['run'],
              suggestion: null,
              aiUsedWords: ['souvenir'], // claimed AND present in the text
            );
          };

          await controller().sendTurn('I ran to the store.');

          expect(state().allWordsUsedCorrectly, {'run'});
          expect(state().independentWordsUsedCorrectly, {'run'});
          expect(state().allWordsUsed, isFalse);
          expect(state().remainingWordsForCowrite, ['souvenir']);
          // The ordinary AI bubble is still shown.
          expect(state().cowriteTranscript, hasLength(2));
          expect(state().cowriteTranscript[1].text, 'I also bought two souvenirs for my sister.');
          expect(fakeAi.forcedTurnCalls, isEmpty);
        },
      );

      test(
        'Bug B (substring rejection): bot response containing only a substring match '
        '(e.g. crunchy for run, unbuttoned for button) does not credit the word',
        () async {
          controller().startFlow(
            studentId: 'student-1',
            wordIds: ['run', 'button'],
            sourceType: LearningSessionSourceType.targetGuru,
          );
          fakeAi.generateStoryHandler = (words, prompt) => GenerateStoryResult(
            story: 'I [[run|ran]] and pressed the [[button|button]].',
            translation: 'T',
          );
          await controller().generateStory(prompt: 'judul');
          await controller().advanceToClozeTest();
          controller().setClozeAnswer('run', 'run');
          controller().setClozeAnswer('button', 'button');
          controller().submitCloze();
          final segments = buildClozeSegments(state().storyContent!);
          await controller().confirmClozeAndAdvance(segments);

          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            return const CowriteTurnResult(
              aiTurn: 'He ate a crunchy apple in his unbuttoned jacket.',
              feedback: 'Bagus!',
              hasError: false,
              wordsUsedCorrectly: [],
              suggestion: null,
              aiUsedWords: ['run', 'button'],
            );
          };

          await controller().sendTurn('I walked to the garden.');

          expect(state().allWordsUsedCorrectly, isEmpty);
          expect(state().independentWordsUsedCorrectly, isEmpty);
        },
      );

      test(
        'Bug B (no double-counting & trailing AI suppression): when the student\'s own '
        'turn completes all remaining target words, a target word appearing in the '
        'unused aiTurn does not prevent trailing AI bubble suppression or corrupt state',
        () async {
          await startThroughCloze();
          // Turn 1: student uses 'run'
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            return const CowriteTurnResult(
              aiTurn: 'Where did you run to?',
              feedback: 'Bagus!',
              hasError: false,
              wordsUsedCorrectly: ['run'],
              suggestion: null,
              aiUsedWords: [],
            );
          };
          await controller().sendTurn('I ran to the market.');
          expect(state().allWordsUsedCorrectly, {'run'});
          expect(state().independentWordsUsedCorrectly, {'run'});
          expect(state().remainingWordsForCowrite, ['souvenir']);

          // Turn 2: student uses 'souvenir' (completing all words!), and the
          // Worker's unused aiTurn also happens to mention 'run' and 'souvenir'.
          fakeAi.cowriteTurnHandler = (transcript, remainingWords, requestSuggestion) {
            expect(remainingWords, ['souvenir']);
            return const CowriteTurnResult(
              aiTurn: 'That souvenir from your run sounds wonderful!',
              feedback: 'Sempurna!',
              hasError: false,
              wordsUsedCorrectly: ['souvenir'],
              suggestion: null,
              aiUsedWords: [],
            );
          };
          await controller().sendTurn('I bought a souvenir there.');

          expect(state().allWordsUsed, isTrue);
          expect(state().allWordsUsedCorrectly, {'run', 'souvenir'});
          expect(state().independentWordsUsedCorrectly, {'run', 'souvenir'});
          // Turn 1 had student + AI (2 bubbles); Turn 2 adds ONLY the student's
          // completing bubble (total 3 bubbles, trailing AI bubble suppressed).
          expect(state().cowriteTranscript, hasLength(3));
          expect(state().cowriteTranscript.last.sender, CowriteSender.siswa);
          expect(state().cowriteTranscript.last.text, 'I bought a souvenir there.');
        },
      );
    });
  });
}
