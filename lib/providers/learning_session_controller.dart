import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/learning_session.dart';
import '../services/ai_worker_service.dart';
import '../utils/cloze_blanks.dart';
import '../utils/cowrite_feedback.dart';
import '../utils/cowrite_suggestion.dart';
import '../utils/cowrite_validator.dart';
import '../utils/normalize_word.dart';
import 'ai_worker_providers.dart';
import 'history_providers.dart';
import 'learning_cart_providers.dart';

part 'learning_session_controller.g.dart';

/// In-progress state for one Storyfier 3-phase flow (`SPEC.md` §5) — the
/// single source of truth `story_reading_screen.dart`/`cloze_test_screen.
/// dart`/`cowrite_screen.dart` all read and drive as the student moves
/// through Fase 1 → 2 → 3. Firestore is the durable record
/// (`learningSessions`/`learningProgress`); this is the client-side
/// working copy that lets the three screens share one flow without
/// re-fetching from Firestore between phases.
class LearningFlowState {
  const LearningFlowState({
    required this.studentId,
    required this.wordIds,
    required this.sourceType,
    this.sessionId,
    this.currentPhase = LearningSessionPhase.membaca,
    this.storyTitle,
    this.storyContent,
    this.storyTranslation,
    this.isGenerating = false,
    this.generateError,
    this.clozeAnswers = const {},
    this.hasSubmittedCloze = false,
    this.clozeTestResult,
    this.cowriteTranscript = const [],
    this.allWordsUsedCorrectly = const {},
    this.independentWordsUsedCorrectly = const {},
    this.usedSuggestionThisTurn = false,
    this.pendingSuggestion,
    this.isSendingTurn = false,
    this.isRequestingSuggestion = false,
    this.consecutiveMissedStudentTurns = 0,
    this.isCompletingCowrite = false,
    this.turnError,
    this.clozeSubmitError,
    this.advanceToClozeError,
  });

  /// The signed-in student this flow belongs to — passed in explicitly by
  /// [LearningFlowController.startFlow] rather than read from auth state
  /// inside this class, so this whole state machine can be driven and
  /// unit-tested with a plain string, no Firebase Auth involved.
  final String studentId;

  /// Already deduped + `normalizeWord()`-ed (see [LearningFlowController.
  /// startFlow]) — the target words for this whole flow, regardless of
  /// entry point.
  final List<String> wordIds;

  /// One of [LearningSessionSourceType].
  final String sourceType;

  /// `null` until the first successful generate creates the Firestore
  /// document (`DATA_MODEL.md` §4).
  final String? sessionId;

  /// One of [LearningSessionPhase] — mirrors the Firestore doc's own
  /// field, updated locally right after each phase-transition write
  /// succeeds.
  final String currentPhase;

  final String? storyTitle;

  /// Still marked (`[[targetWord|usedForm]]`) — never stripped in state,
  /// only when actually rendering plain text.
  final String? storyContent;
  final String? storyTranslation;

  final bool isGenerating;

  /// Friendly, student-facing message (`DESIGN_REFERENCE.md` §3.4/§5.8) —
  /// never a raw exception. `null` means no current error.
  final String? generateError;

  /// Fase 2's current answers: `{targetWord: selectedBaseFormOrNull}`.
  final Map<String, String?> clozeAnswers;

  /// Whether "Submit" has been tapped at least once — reveals grading
  /// colors + the "Selanjutnya" button. Grading itself is always
  /// recomputed live from [clozeAnswers] (via `gradeClozeAnswers`), not
  /// cached here, so further answer changes after Submit update the
  /// colors immediately without needing another explicit Submit tap.
  final bool hasSubmittedCloze;

  /// The **final** graded result, set only once "Selanjutnya" actually
  /// writes it to Firestore (`DATA_MODEL.md` §4's `clozeTestResult`
  /// shape) — `null` before that point, even if [hasSubmittedCloze] is
  /// already true.
  final Map<String, bool>? clozeTestResult;

  final List<CowriteTurn> cowriteTranscript;

  /// Session-level `wordUsedCorrectly`: target words validly used so far
  /// by the student (suggestion-assisted or not) **or** by the bot in an
  /// application-forced fallback turn whose text was validated to contain
  /// the selected word. Drives the co-write pill display ("terpakai/belum
  /// terpakai") and the auto-stop condition (`SPEC.md` §5.3), which is
  /// about usage, not independence. A target word appearing incidentally
  /// in an ordinary AI turn is never added here.
  final Set<String> allWordsUsedCorrectly;

  /// Subset of [allWordsUsedCorrectly] used correctly on a turn that did
  /// **not** use "saran menulis" (`DATA_MODEL.md` §10.2's "mandiri"
  /// rule) — this, not [allWordsUsedCorrectly], is what gets written as
  /// `cowriteWordsUsedCorrectly` and feeds the mastery upgrade.
  final Set<String> independentWordsUsedCorrectly;

  /// Whether the student has requested a suggestion for their *current*,
  /// not-yet-sent turn — disqualifies that turn from "mandiri" the moment
  /// it's requested, regardless of whether the sent text matches the
  /// suggestion verbatim (`DESIGN_REFERENCE.md` §3.6).
  final bool usedSuggestionThisTurn;

  /// The last fetched suggestion text, shown near the input until the
  /// student sends a turn or asks for a fresh one.
  final String? pendingSuggestion;

  /// True for the whole send cycle — the ordinary Worker call and, when
  /// due, the forced-word fallback call.
  final bool isSendingTurn;
  final bool isRequestingSuggestion;

  /// Application-owned counter of consecutive **accepted** student turns
  /// with no valid target-word usage. Incremented only by a student turn
  /// that was sent and graded with no newly validated target word; reset
  /// to 0 when a student turn validly uses at least one remaining target
  /// word, and when a forced fallback turn succeeds. Never changed by AI
  /// turns, locally rejected inputs, or failed sends. When it reaches
  /// `kCowriteFallbackMissThreshold` (3) and words remain, the next bot
  /// turn is an application-forced fallback (see
  /// [LearningFlowController.sendTurn]); a failed fallback leaves it at
  /// 3+, so the next missed turn retries the fallback.
  final int consecutiveMissedStudentTurns;

  /// True while "✓ Selesai" is writing the session — guards against a
  /// double tap writing the completion twice.
  final bool isCompletingCowrite;

  /// Friendly, student-facing message for a failed send/suggestion call —
  /// or, since Milestone 7 Phase 2 Stage 3, a failed [LearningFlowController.
  /// completeCowrite] ("✓ Selesai") — both are Fase 3 write failures shown
  /// in the same spot on `cowrite_screen.dart`, so one field covers both.
  final String? turnError;

  /// Friendly, student-facing message for a failed [LearningFlowController.
  /// confirmClozeAndAdvance] (Fase 2 → Fase 3 "Selanjutnya"). Separate from
  /// [turnError] since it's shown on a different screen (`cloze_test_screen.
  /// dart`, before Fase 3 is ever reached) — Milestone 7 Phase 2 Stage 3.
  final String? clozeSubmitError;

  /// Friendly, student-facing message for a failed [LearningFlowController.
  /// advanceToClozeTest] (Fase 1 → Fase 2 "Selanjutnya"). Separate from
  /// [generateError] (a different action, same screen — retrying this one
  /// should re-attempt the phase advance, not re-generate the story) and
  /// from [clozeSubmitError] (a different screen) — Milestone 7 Phase 2
  /// Stage 6.
  final String? advanceToClozeError;

  /// All target words used correctly, independently or not — the
  /// condition that ends the conversation (`SPEC.md` §5.3).
  bool get allWordsUsed => wordIds.every(allWordsUsedCorrectly.contains);

  /// Target words the Worker still needs to try to elicit — sent as
  /// `/cowrite-turn`'s `remainingWords` (`DATA_MODEL.md` §10.2).
  List<String> get remainingWordsForCowrite =>
      [for (final w in wordIds) if (!allWordsUsedCorrectly.contains(w))w];

  LearningFlowState copyWith({
    String? sessionId,
    String? currentPhase,
    String? storyTitle,
    String? storyContent,
    Object? storyTranslation = _unset,
    bool? isGenerating,
    Object? generateError = _unset,
    Map<String, String?>? clozeAnswers,
    bool? hasSubmittedCloze,
    Object? clozeTestResult = _unset,
    List<CowriteTurn>? cowriteTranscript,
    Set<String>? allWordsUsedCorrectly,
    Set<String>? independentWordsUsedCorrectly,
    bool? usedSuggestionThisTurn,
    Object? pendingSuggestion = _unset,
    bool? isSendingTurn,
    bool? isRequestingSuggestion,
    int? consecutiveMissedStudentTurns,
    bool? isCompletingCowrite,
    Object? turnError = _unset,
    Object? clozeSubmitError = _unset,
    Object? advanceToClozeError = _unset,
  }) {
    return LearningFlowState(
      studentId: studentId,
      wordIds: wordIds,
      sourceType: sourceType,
      sessionId: sessionId ?? this.sessionId,
      currentPhase: currentPhase ?? this.currentPhase,
      storyTitle: storyTitle ?? this.storyTitle,
      storyContent: storyContent ?? this.storyContent,
      storyTranslation: identical(storyTranslation, _unset)
          ? this.storyTranslation
          : storyTranslation as String?,
      isGenerating: isGenerating ?? this.isGenerating,
      generateError: identical(generateError, _unset)
          ? this.generateError
          : generateError as String?,
      clozeAnswers: clozeAnswers ?? this.clozeAnswers,
      hasSubmittedCloze: hasSubmittedCloze ?? this.hasSubmittedCloze,
      clozeTestResult: identical(clozeTestResult, _unset)
          ? this.clozeTestResult
          : clozeTestResult as Map<String, bool>?,
      cowriteTranscript: cowriteTranscript ?? this.cowriteTranscript,
      allWordsUsedCorrectly: allWordsUsedCorrectly ?? this.allWordsUsedCorrectly,
      independentWordsUsedCorrectly:
          independentWordsUsedCorrectly ?? this.independentWordsUsedCorrectly,
      usedSuggestionThisTurn: usedSuggestionThisTurn ?? this.usedSuggestionThisTurn,
      pendingSuggestion: identical(pendingSuggestion, _unset)
          ? this.pendingSuggestion
          : pendingSuggestion as String?,
      isSendingTurn: isSendingTurn ?? this.isSendingTurn,
      isRequestingSuggestion: isRequestingSuggestion ?? this.isRequestingSuggestion,
      consecutiveMissedStudentTurns:
          consecutiveMissedStudentTurns ?? this.consecutiveMissedStudentTurns,
      isCompletingCowrite: isCompletingCowrite ?? this.isCompletingCowrite,
      turnError: identical(turnError, _unset) ? this.turnError : turnError as String?,
      clozeSubmitError: identical(clozeSubmitError, _unset)
          ? this.clozeSubmitError
          : clozeSubmitError as String?,
      advanceToClozeError: identical(advanceToClozeError, _unset)
          ? this.advanceToClozeError
          : advanceToClozeError as String?,
    );
  }
}

/// Sentinel distinguishing "not passed" from "explicitly passed null" in
/// [LearningFlowState.copyWith] — same pattern
/// `VocabBrowserFilterState.copyWith`'s `clearTopic`/`clearPos` flags
/// solve differently; this file uses the sentinel-object form instead
/// since several nullable fields need it here.
const Object _unset = Object();

/// Source of randomness for the Co-Write fallback's word selection
/// (`selectFallbackWord`) — a provider so tests can inject a seeded or
/// scripted [Random] and assert exactly which word was forced.
@Riverpod(keepAlive: true)
Random cowriteFallbackRandom(Ref ref) => Random();

/// Drives one Storyfier flow end-to-end (`SPEC.md` §5): Fase 1 generate/
/// regenerate, Fase 2 grading, Fase 3 chat — writing to
/// `learningSessions`/`learningProgress` at exactly the points
/// `DATA_MODEL.md` §4/§3 and the project owner's Milestone 7 decisions
/// specify. `keepAlive: true` (like `LearningCart`, unlike screen-local
/// `VocabBrowserFilter`) because this state must survive
/// `Navigator.push`ing from Fase 1 → 2 → 3 across three separate screens.
///
/// **No resume logic** (Decision 1): [startFlow] always begins a fresh
/// [LearningFlowState] with `sessionId: null` — an abandoned previous
/// flow's Firestore document, if any, is simply left as-is.
@Riverpod(keepAlive: true)
class LearningFlowController extends _$LearningFlowController {
  /// Incremented by [startFlow]. An in-flight Worker response whose epoch
  /// no longer matches belongs to a previous flow and is dropped instead of
  /// being attached to the current flow's transcript.
  int _flowEpoch = 0;

  @override
  LearningFlowState build() {
    return const LearningFlowState(studentId: '', wordIds: [], sourceType: '');
  }

  /// Starts a brand-new flow for [wordIds]/[sourceType] — called by each
  /// of the three entry points right before pushing
  /// `StoryReadingScreen`. [studentId] is passed in by the caller (each
  /// entry-point screen already knows the signed-in student) rather than
  /// read from auth state inside this class, so the whole flow can be
  /// driven and unit-tested with a plain string. Words are deduped (by
  /// `normalizeWord()`) as defensive normalization: nothing today should
  /// hand this a list with duplicates, but a duplicate target word sent
  /// to `/generate-story` would be wasteful at best (`DATA_MODEL.md`
  /// §10.2 has no defined behavior for it either).
  void startFlow({
    required String studentId,
    required List<String> wordIds,
    required String sourceType,
  }) {
    final deduped = <String>[];
    final seen = <String>{};
    for (final raw in wordIds) {
      final normalized = normalizeWord(raw);
      if (seen.add(normalized)) deduped.add(normalized);
    }
    _flowEpoch++;
    state = LearningFlowState(studentId: studentId, wordIds: deduped, sourceType: sourceType);
  }

  /// Fase 1's "Generate"/"Generate ulang" (`SPEC.md` §5.1). Calls the
  /// Worker first; only on success does it touch Firestore — a
  /// story-generation failure must never leave a half-written session
  /// (`DESIGN_REFERENCE.md` §3.4's error-state requirement).
  ///
  /// Milestone 7 Phase 2 Stage 7: a no-op once [LearningFlowState.
  /// currentPhase] has moved past `membaca` — e.g. the student pressed the
  /// system/AppBar Back button from Cloze Test back to this screen, whose
  /// Firestore session already durably advanced. `overwriteStory()` would
  /// hit `firestore.rules`' one-way phase lock (only permitted while
  /// `currentPhase == membaca`) and fail with permission-denied — not a
  /// rules defect, just an attempt to modify a story that's already
  /// locked. `story_reading_screen.dart` disables the Generate/Generate
  /// Ulang button in this state, so this guard is mostly defense-in-depth
  /// against reaching this method another way; it stays a silent no-op
  /// (not an error) since there is nothing wrong to report — the button
  /// simply shouldn't have been tappable.
  Future<void> generateStory({required String prompt}) async {
    if (state.currentPhase != LearningSessionPhase.membaca) return;

    state = state.copyWith(isGenerating: true, generateError: null);

    try {
      final result = await ref
          .read(aiWorkerServiceProvider)
          .generateStory(targetWords: state.wordIds, prompt: prompt);

      // Milestone 7 Phase 2 Stage 2: don't trust the Worker's own
      // exactly-once marker validation (Stage 1) alone — cross-check the
      // returned story client-side too, before it's ever written to
      // Firestore or shown to the student. A mismatch here (missing,
      // duplicate, extra/hallucinated, or spelling/case-mismatched
      // marker) is treated exactly like any other failed generation:
      // same `generateError`/"Coba lagi" recovery path, no session
      // created/overwritten, no story committed to state.
      if (!storyMarkersMatchWordIds(result.story, state.wordIds)) {
        state = state.copyWith(
          isGenerating: false,
          generateError:
              'Cerita yang dihasilkan tidak sesuai dengan kata target. Coba generate ulang.',
        );
        return;
      }

      final isFirstGenerate = state.sessionId == null;

      if (isFirstGenerate) {
        final sessionId = await ref
            .read(learningSessionServiceProvider)
            .createSession(
              studentId: state.studentId,
              wordIds: state.wordIds,
              sourceType: state.sourceType,
              storyTitle: prompt,
              storyContent: result.story,
              storyTranslation: result.translation,
            );
        state = state.copyWith(sessionId: sessionId);
      } else {
        await ref
            .read(learningSessionServiceProvider)
            .overwriteStory(
              sessionId: state.sessionId!,
              storyTitle: prompt,
              storyContent: result.story,
              storyTranslation: result.translation,
            );
      }

      state = state.copyWith(
        storyTitle: prompt,
        storyContent: result.story,
        storyTranslation: result.translation,
        isGenerating: false,
      );

      // Decision 4 (project owner, Milestone 7): the cart is cleared only
      // once the *initial* generate for a `keranjangPelajari` flow
      // actually succeeds — never on failure, and never on a later
      // regenerate (the cart was already emptied by the first success).
      if (isFirstGenerate && state.sourceType == LearningSessionSourceType.keranjangPelajari) {
        ref.read(learningCartProvider.notifier).clear();
      }
    } catch (error, stackTrace) {
      debugPrint('LearningFlowController.generateStory failed: $error\n$stackTrace');
      state = state.copyWith(
        isGenerating: false,
        generateError: 'Gagal membuat cerita. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  /// Fase 1 → Fase 2 ("Selanjutnya", `SPEC.md` §5.1). The story fields
  /// themselves are already correct from the last successful
  /// [generateStory] call — this only moves the phase forward, which is
  /// what actually locks them (`DATA_MODEL.md` §4).
  ///
  /// Milestone 7 Phase 2 Stage 6: wrapped in try/catch, same pattern
  /// Stage 3 already applied to [confirmClozeAndAdvance]/[completeCowrite]
  /// — this was the one remaining phase-transition write without it (a
  /// live-reported permission-denied here was previously an unhandled
  /// exception with no student-facing feedback at all). On failure,
  /// [LearningFlowState.currentPhase] is left untouched (still
  /// `membaca`), so the student stays on the Reading screen and can retry
  /// by tapping "Selanjutnya" again. Callers must check
  /// [LearningFlowState.advanceToClozeError] after awaiting this before
  /// navigating on to Fase 2 — this method no longer throws, so a bare
  /// `await` alone is not enough to detect failure.
  ///
  /// Milestone 7 Phase 2 Stage 7: if [LearningFlowState.currentPhase] is
  /// already past `membaca` (the student came back via Back after this
  /// exact transition already succeeded once), this is a no-op that skips
  /// the Firestore write entirely — retrying it would hit
  /// `firestore.rules`' one-way phase lock (only permitted from
  /// `membaca`) and fail with permission-denied, even though nothing is
  /// actually wrong. Clearing [LearningFlowState.advanceToClozeError] and
  /// returning lets the caller's existing "error == null -> navigate"
  /// check take the student straight to `ClozeTestScreen`, exactly as if
  /// the write had succeeded again.
  Future<void> advanceToClozeTest() async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;

    if (state.currentPhase != LearningSessionPhase.membaca) {
      state = state.copyWith(advanceToClozeError: null);
      return;
    }

    state = state.copyWith(advanceToClozeError: null);
    try {
      await ref.read(learningSessionServiceProvider).advanceToClozeTest(sessionId);
      state = state.copyWith(currentPhase: LearningSessionPhase.clozeTest);
    } catch (error, stackTrace) {
      debugPrint('LearningFlowController.advanceToClozeTest failed: $error\n$stackTrace');
      state = state.copyWith(
        advanceToClozeError: 'Gagal melanjutkan ke Cloze Test. Coba lagi.',
      );
    }
  }

  void setClozeAnswer(String targetWord, String? answer) {
    state = state.copyWith(clozeAnswers: {...state.clozeAnswers, targetWord: answer});
  }

  /// Fase 2's "Submit" (`DESIGN_REFERENCE.md` §3.5) — reveals grading
  /// colors and the "Selanjutnya" button. Does **not** write anything to
  /// Firestore yet; the student may still change answers afterward
  /// (`SPEC.md` §5.2: "bisa perbaiki jawaban yang salah secara
  /// iteratif"), which just recomputes the same live grading.
  void submitCloze() {
    state = state.copyWith(hasSubmittedCloze: true);
  }

  /// Fase 2 → Fase 3 ("Selanjutnya", shown after Submit). Writes the
  /// final `clozeTestResult` computed from whatever [state.clozeAnswers]
  /// holds *at this moment* (`SPEC.md` §5.2: the iteratively-corrected
  /// answers), then — per the project owner's Milestone 7 Decision 3 —
  /// immediately writes `learningProgress` for every session word.
  ///
  /// Milestone 7 Phase 2 Stage 3: wrapped in try/catch, same pattern as
  /// [generateStory]/[sendTurn] — a write failure here must not silently
  /// advance the phase. On failure, [LearningFlowState.currentPhase]/
  /// [LearningFlowState.clozeTestResult] are left completely untouched
  /// (still `clozeTest`/`null`), so the student stays on the Cloze screen
  /// and can safely retry by tapping "Selanjutnya" again. Callers must
  /// check [LearningFlowState.clozeSubmitError] after awaiting this before
  /// navigating on to Fase 3 — this method no longer throws, so a bare
  /// `await` alone is not enough to detect failure.
  Future<void> confirmClozeAndAdvance(List<ClozeSegment> segments) async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;

    state = state.copyWith(clozeSubmitError: null, turnError: null);
    final result = gradeClozeAnswers(segments, state.clozeAnswers);

    try {
      await ref
          .read(learningSessionServiceProvider)
          .recordClozeResult(sessionId: sessionId, clozeTestResult: result);
      await ref
          .read(learningProgressServiceProvider)
          .recordClozeCompletion(
            studentId: state.studentId,
            wordIds: state.wordIds,
            sessionId: sessionId,
          );

      state = state.copyWith(
        clozeTestResult: result,
        currentPhase: LearningSessionPhase.coWrite,
        turnError: null,
      );
    } catch (error, stackTrace) {
      debugPrint('LearningFlowController.confirmClozeAndAdvance failed: $error\n$stackTrace');
      state = state.copyWith(
        clozeSubmitError: 'Gagal menyimpan hasil Cloze Test. Coba lagi.',
      );
    }
  }

  /// Fase 3's "Saran menulis" (`SPEC.md` §5.3). Does not touch the
  /// transcript or any word status — the Worker's suggestion mode returns
  /// only a bare English sentence ([CowriteTurnResult.suggestion]), stored
  /// in [LearningFlowState.pendingSuggestion] and shown with an Indonesian
  /// instruction (`formatWritingSuggestion`). Requesting one disqualifies
  /// the next sent turn from "mandiri" (`DATA_MODEL.md` §10.2).
  ///
  /// Ignored while a turn is being sent (or the session is complete): a
  /// suggestion computed against a transcript that is about to change
  /// would be stale, and would wrongly mark the *next* turn as assisted.
  Future<void> requestSuggestion() async {
    if (state.isSendingTurn || state.isRequestingSuggestion || state.allWordsUsed) return;
    final epoch = _flowEpoch;

    state = state.copyWith(isRequestingSuggestion: true, turnError: null);
    try {
      final result = await ref
          .read(aiWorkerServiceProvider)
          .cowriteTurn(
            transcript: _transcriptPayload(),
            remainingWords: state.remainingWordsForCowrite,
            requestSuggestion: true,
          );
      if (epoch != _flowEpoch) return;

      final sentence = extractSuggestedSentence(result.suggestion ?? '');
      state = state.copyWith(
        isRequestingSuggestion: false,
        usedSuggestionThisTurn: true,
        pendingSuggestion: sentence.isEmpty ? null : sentence,
      );
    } catch (error, stackTrace) {
      if (epoch != _flowEpoch) return;
      debugPrint('LearningFlowController.requestSuggestion failed: $error\n$stackTrace');
      state = state.copyWith(
        isRequestingSuggestion: false,
        turnError: 'Gagal mengambil saran menulis. Coba lagi.',
      );
    }
  }

  /// Fase 3's send action. The application owns every decision here; the
  /// Worker only generates text and its output is validated before it can
  /// change any state:
  ///
  /// 1. **Local rejection.** A turn that mentions a target word only as a
  ///    bare word, fragment, or list ([shouldRejectStudentTurnLocally]) is
  ///    rejected with [kBareOrFragmentTurnErrorMessage]: no Worker call, no
  ///    transcript entry, no AI turn, counter unchanged. Ordinary replies
  ///    with no target word ("Okay.") are accepted as normal turns.
  /// 2. **Ordinary call.** The student's turn is appended immediately
  ///    (Stage 6), then `/cowrite-turn` assesses exactly this turn. The
  ///    response is attached only to the turn that was sent: it is dropped
  ///    if the flow was restarted meanwhile ([_flowEpoch]), and treated as
  ///    a failed send if the Worker's `assessedStudentTurn` doesn't match.
  /// 3. **Student credit.** `validateStudentTargetWords` against the words
  ///    remaining *before* this turn. Validated words always count toward
  ///    session coverage ([LearningFlowState.allWordsUsedCorrectly]). They
  ///    also count as independent use ("mandiri") only when the turn did
  ///    not use a suggestion ([LearningFlowState.usedSuggestionThisTurn] at
  ///    send time) **and** is not Indonesian/mixed-language
  ///    (`containsIndonesianWords`, decided here in app code and sent to the
  ///    Worker as `studentTurnContainsIndonesian` so feedback can remind the
  ///    student to write in English).
  ///    **Feedback (CW-02):** the Worker's feedback is attached to this turn
  ///    only, replaced by [kCowriteUncreditedClaimFeedback] if it claimed
  ///    words that validation rejected, and given a display-only
  ///    [CowriteFeedbackKind] from the validated result
  ///    ([classifyCowriteFeedback]) — never from its wording, and never
  ///    affecting coverage or mastery.
  /// 4. **Counter.** [LearningFlowState.consecutiveMissedStudentTurns]
  ///    resets to 0 if this turn validly used a remaining target word,
  ///    otherwise increments.
  /// 5. **Bot turn.** If no words remain, the session is complete and no
  ///    AI bubble is appended. Else, if the counter has reached
  ///    [kCowriteFallbackMissThreshold], the app picks exactly one
  ///    remaining word at random ([selectFallbackWord]) and asks the Worker
  ///    for a forced-word turn; the word is marked used only if it is
  ///    detected in the returned text (`validateBotTargetWords`), and the
  ///    counter then resets. If that call fails or doesn't validate, the
  ///    ordinary AI turn is shown instead, nothing is marked, and the
  ///    counter stays at 3+ so the next missed turn retries. Otherwise the
  ///    ordinary AI turn is shown and never credits any target word, even
  ///    if it happens to contain one — so incidental bot use can't bypass
  ///    the fallback schedule.
  ///
  /// The whole transcript is persisted after every turn (Decision 1). If
  /// the ordinary call fails, the optimistic student turn is rolled back.
  Future<void> sendTurn(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty ||
        state.isSendingTurn ||
        state.isRequestingSuggestion ||
        state.allWordsUsed) {
      return;
    }

    if (shouldRejectStudentTurnLocally(trimmed, state.wordIds)) {
      state = state.copyWith(
        isSendingTurn: false,
        turnError: kBareOrFragmentTurnErrorMessage,
      );
      return;
    }

    final epoch = _flowEpoch;
    final usedSuggestion = state.usedSuggestionThisTurn;
    final mixedLanguage = containsIndonesianWords(trimmed, state.wordIds);
    final transcriptBeforeSend = state.cowriteTranscript;
    final remainingBeforeTurn = state.remainingWordsForCowrite;

    state = state.copyWith(
      cowriteTranscript: [
        ...transcriptBeforeSend,
        CowriteTurn(
          sender: CowriteSender.siswa,
          text: trimmed,
          // Filled in once the Worker responds, below — the message
          // itself must not wait for that.
          feedback: null,
          usedSuggestion: usedSuggestion,
        ),
      ],
      isSendingTurn: true,
      turnError: null,
    );
    final payloadWithStudentTurn = _transcriptPayload();

    final CowriteTurnResult result;
    try {
      result = await ref
          .read(aiWorkerServiceProvider)
          .cowriteTurn(
            transcript: payloadWithStudentTurn,
            remainingWords: remainingBeforeTurn,
            requestSuggestion: false,
            studentTurnContainsIndonesian: mixedLanguage,
          );
      if (epoch != _flowEpoch) return;
      final assessed = result.assessedStudentTurn;
      if (assessed != null && assessed.trim() != trimmed) {
        throw AiWorkerException(
          'Worker assessed a different student turn ("$assessed") than the one sent.',
        );
      }
    } catch (error, stackTrace) {
      if (epoch != _flowEpoch) return;
      debugPrint('LearningFlowController.sendTurn failed: $error\n$stackTrace');
      state = state.copyWith(
        cowriteTranscript: transcriptBeforeSend,
        isSendingTurn: false,
        turnError: 'Gagal mengirim giliran. Coba lagi.',
      );
      return;
    }

    final usedCorrectlyThisTurn = validateStudentTargetWords(
      claimedWords: result.wordsUsedCorrectly,
      studentTurnText: trimmed,
      eligibleTargetWords: remainingBeforeTurn,
    ).toSet();
    // CW-02: feedback text and its display kind are fixed here, from this
    // turn's validated result, and attached only to this turn below.
    final studentFeedback = reconcileCowriteFeedback(
      workerFeedback: result.feedback,
      claimedWords: result.wordsUsedCorrectly,
      creditedWords: usedCorrectlyThisTurn,
      studentTurnContainsIndonesian: mixedLanguage,
    );
    final studentFeedbackKind = studentFeedback == null
        ? null
        : classifyCowriteFeedback(
            studentTurnContainsIndonesian: mixedLanguage,
            creditedWords: usedCorrectlyThisTurn,
            attemptedTargetWord: containsAnyTargetWord(trimmed, remainingBeforeTurn),
            hasError: result.hasError,
          );
    final wordsUsedAfterStudentTurn = {
      ...state.allWordsUsedCorrectly,
      ...usedCorrectlyThisTurn,
    };
    final remainingAfterStudentTurn = [
      for (final word in state.wordIds)
        if (!wordsUsedAfterStudentTurn.contains(word)) word,
    ];
    var missedTurns = usedCorrectlyThisTurn.isEmpty
        ? state.consecutiveMissedStudentTurns + 1
        : 0;

    String? botText;
    final botWordsThisTurn = <String>{};
    if (remainingAfterStudentTurn.isNotEmpty) {
      // Ordinary continuation — shown, but never credits a target word.
      botText = result.aiTurn;

      if (missedTurns >= kCowriteFallbackMissThreshold) {
        final forcedWord = selectFallbackWord(
          remainingAfterStudentTurn,
          ref.read(cowriteFallbackRandomProvider),
        )!;
        try {
          final forced = await ref
              .read(aiWorkerServiceProvider)
              .cowriteForcedTurn(
                transcript: payloadWithStudentTurn,
                remainingWords: remainingAfterStudentTurn,
                forcedWord: forcedWord,
              );
          if (epoch != _flowEpoch) return;
          // Detected from the actual text; the Worker's aiUsedWords claim
          // is deliberately not consulted.
          final validated = validateBotTargetWords(
            claimedWords: const [],
            aiTurnText: forced.aiTurn,
            eligibleTargetWords: [forcedWord],
          );
          if (validated.isNotEmpty) {
            botText = forced.aiTurn;
            botWordsThisTurn.addAll(validated);
            missedTurns = 0;
          } else {
            debugPrint(
              'LearningFlowController: forced turn did not contain "$forcedWord"; '
              'keeping the ordinary AI turn and retrying on the next missed turn.',
            );
          }
        } catch (error, stackTrace) {
          if (epoch != _flowEpoch) return;
          debugPrint(
            'LearningFlowController: forced turn for "$forcedWord" failed: '
            '$error\n$stackTrace',
          );
        }
      }
    }

    final updatedTranscript = [
      ...transcriptBeforeSend,
      CowriteTurn(
        sender: CowriteSender.siswa,
        text: trimmed,
        feedback: studentFeedback,
        usedSuggestion: usedSuggestion,
        feedbackKind: studentFeedbackKind,
      ),
      if (botText != null && botText.trim().isNotEmpty)
        CowriteTurn(
          sender: CowriteSender.ai,
          text: botText.trim(),
          feedback: null,
          usedSuggestion: false,
        ),
    ];

    state = state.copyWith(
      cowriteTranscript: updatedTranscript,
      allWordsUsedCorrectly: {...wordsUsedAfterStudentTurn, ...botWordsThisTurn},
      // Bot usage never reaches the independent (mastery) set, and neither
      // does a suggestion-assisted or Indonesian/mixed-language turn — those
      // count for session coverage (above) only.
      independentWordsUsedCorrectly: usedSuggestion || mixedLanguage
          ? state.independentWordsUsedCorrectly
          : {...state.independentWordsUsedCorrectly, ...usedCorrectlyThisTurn},
      consecutiveMissedStudentTurns: missedTurns,
      usedSuggestionThisTurn: false,
      pendingSuggestion: null,
      isSendingTurn: false,
    );

    // Debug builds only: never logs student text in release builds.
    if (kDebugMode) {
      debugPrint(
        '[COWRITE DIAGNOSTIC]\n'
        'Student turn: $trimmed\n'
        'Worker wordsUsedCorrectly: ${result.wordsUsedCorrectly}\n'
        'Validated student words: $usedCorrectlyThisTurn\n'
        'Indonesian/mixed-language turn: $mixedLanguage\n'
        'Validated bot (forced) words: $botWordsThisTurn\n'
        'Consecutive missed turns: $missedTurns\n'
        'All words used: ${state.allWordsUsed}',
      );
    }

    final sessionId = state.sessionId;
    if (sessionId != null) {
      try {
        await ref
            .read(learningSessionServiceProvider)
            .saveCowriteTranscript(sessionId: sessionId, transcript: state.cowriteTranscript);
      } catch (error, stackTrace) {
        // The turn itself already succeeded and is reflected in the UI —
        // the next successful save rewrites the whole transcript anyway
        // (see `saveCowriteTranscript`'s doc comment), so this self-heals.
        debugPrint('LearningFlowController: saveCowriteTranscript failed: $error\n$stackTrace');
      }
    }
  }

  /// Fase 3 → `selesai` (`SPEC.md` §5.3's "✓ Selesai" button, shown once
  /// [LearningFlowState.allWordsUsed] is true). Writes the session's
  /// final fields, then the second (and last) mastery write — using only
  /// [LearningFlowState.independentWordsUsedCorrectly], never bot usage.
  ///
  /// Guarded by [LearningFlowState.isCompletingCowrite] (and a no-op once
  /// `selesai`), so a double tap cannot write the completion twice. On
  /// failure, [LearningFlowState.currentPhase] stays `coWrite` and
  /// [LearningFlowState.turnError] is set, so the student can retry —
  /// callers must check the phase after awaiting this (it never throws).
  Future<void> completeCowrite() async {
    final sessionId = state.sessionId;
    final clozeTestResult = state.clozeTestResult;
    if (sessionId == null || clozeTestResult == null) return;
    if (state.isCompletingCowrite ||
        state.currentPhase == LearningSessionPhase.selesai ||
        !state.allWordsUsed) {
      return;
    }

    final independentWords = state.independentWordsUsedCorrectly.toList();
    state = state.copyWith(turnError: null, isCompletingCowrite: true);

    try {
      await ref
          .read(learningSessionServiceProvider)
          .completeSession(
            sessionId: sessionId,
            transcript: state.cowriteTranscript,
            cowriteWordsUsedCorrectly: independentWords,
          );
      await ref
          .read(learningProgressServiceProvider)
          .recordCowriteCompletion(
            studentId: state.studentId,
            clozeTestResult: clozeTestResult,
            cowriteWordsUsedCorrectly: independentWords,
            sessionId: sessionId,
          );

      state = state.copyWith(
        currentPhase: LearningSessionPhase.selesai,
        isCompletingCowrite: false,
      );
    } catch (error, stackTrace) {
      debugPrint('LearningFlowController.completeCowrite failed: $error\n$stackTrace');
      state = state.copyWith(
        turnError: 'Gagal menyelesaikan sesi. Coba lagi.',
        isCompletingCowrite: false,
      );
    }
  }

  List<Map<String, String>> _transcriptPayload() {
    return [
      for (final turn in state.cowriteTranscript) {'sender': turn.sender, 'text': turn.text},
    ];
  }
}

/// User-facing Indonesian feedback shown when a student's input mentions a
/// target word only as a bare word, repeated word, short determiner/
/// preposition fragment, or list of target words instead of a complete
/// English sentence/clause (`shouldRejectStudentTurnLocally`).
const String kBareOrFragmentTurnErrorMessage =
    'Tulis kalimat lengkap dalam bahasa Inggris yang menggunakan kata target, bukan hanya kata lepas.';
