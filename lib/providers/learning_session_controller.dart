import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/learning_session.dart';
import '../services/ai_worker_service.dart';
import '../utils/cloze_blanks.dart';
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

  /// Target words the Worker has reported as "used correctly" in **any**
  /// turn so far (suggestion-assisted or not) — drives the co-write
  /// pill display ("terpakai/belum terpakai") and the auto-stop
  /// condition (`SPEC.md` §5.3: "Percakapan berhenti otomatis begitu
  /// semua kata target sudah dipakai"), which is about usage, not
  /// independence.
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

  final bool isSendingTurn;
  final bool isRequestingSuggestion;

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

    state = state.copyWith(clozeSubmitError: null);
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
      );
    } catch (error, stackTrace) {
      debugPrint('LearningFlowController.confirmClozeAndAdvance failed: $error\n$stackTrace');
      state = state.copyWith(
        clozeSubmitError: 'Gagal menyimpan hasil Cloze Test. Coba lagi.',
      );
    }
  }

  /// Fase 3's "Saran menulis" (`SPEC.md` §5.3). Deliberately does **not**
  /// touch [state.cowriteTranscript]/[state.allWordsUsedCorrectly] —
  /// `vocably-ai-worker/src/handlers/cowriteTurn.ts`'s contract is built
  /// around grading the student's *latest sent* turn and producing the
  /// AI's *next* turn in one call, with the requested suggestion riding
  /// along for the turn the student hasn't written yet. Since no new
  /// student turn exists yet when this is called, this implementation
  /// re-sends the existing transcript unchanged and keeps only
  /// [CowriteTurnResult.suggestion] from the response — the returned
  /// `aiTurn`/`feedback`/`wordsUsedCorrectly` (which would just
  /// re-describe the already-processed previous turn) are intentionally
  /// discarded, not appended again.
  Future<void> requestSuggestion() async {
    state = state.copyWith(isRequestingSuggestion: true, turnError: null);
    try {
      final result = await ref
          .read(aiWorkerServiceProvider)
          .cowriteTurn(
            transcript: _transcriptPayload(),
            remainingWords: state.remainingWordsForCowrite,
            requestSuggestion: true,
          );
      state = state.copyWith(
        isRequestingSuggestion: false,
        usedSuggestionThisTurn: true,
        pendingSuggestion: result.suggestion,
      );
    } catch (error, stackTrace) {
      debugPrint('LearningFlowController.requestSuggestion failed: $error\n$stackTrace');
      state = state.copyWith(
        isRequestingSuggestion: false,
        turnError: 'Gagal mengambil saran menulis. Coba lagi.',
      );
    }
  }

  /// Fase 3's send action — appends the student's [text] as a new turn,
  /// gets the Worker's feedback + the AI's reply, and updates the
  /// "used"/"used independently" tracking (`DATA_MODEL.md` §10.2's
  /// "mandiri" rule: [LearningFlowState.usedSuggestionThisTurn] at the
  /// moment of sending — not whether [text] happens to match the
  /// suggestion verbatim — decides whether this turn's correctly-used
  /// words count toward independent use).
  ///
  /// Persists the whole transcript to Firestore after every turn (project
  /// owner's Decision 1: an abandoned session "remains stored at its last
  /// persisted phase/state" — for that to mean anything during Fase 3,
  /// each turn needs to actually land, not just the final one).
  ///
  /// Milestone 7 Phase 2 Stage 6: the student's own turn is appended to
  /// [LearningFlowState.cowriteTranscript] **immediately**, before the
  /// Worker call — a real chat app shows the sent message right away, not
  /// only once a reply comes back (the previous version built the whole
  /// updated transcript, student turn included, only *after* `await`ing
  /// the Worker, so the student's message and the AI's reply appeared
  /// together, visibly delayed). If the Worker call fails, the
  /// optimistically-added turn is rolled back — the existing, intentional
  /// contract (a failed send leaves no trace in the transcript once the
  /// failure is fully handled) is preserved; only the *timing* of the
  /// success path changed, not the failure outcome.
  Future<void> sendTurn(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSendingTurn) return;

    final usedSuggestion = state.usedSuggestionThisTurn;
    final transcriptBeforeSend = state.cowriteTranscript;

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

    try {
      final result = await ref
          .read(aiWorkerServiceProvider)
          .cowriteTurn(
            transcript: _transcriptPayload(),
            remainingWords: state.remainingWordsForCowrite,
            requestSuggestion: false,
          );

      // Client-side safety guard (Milestone 7 Phase 2 Stage 8 follow-up):
      // live testing found the Worker's own `wordsUsedCorrectly`
      // occasionally including a bare word (e.g. the student just types
      // "breakfast") even though its own feedback correctly recognized it
      // wasn't a real sentence. Rather than trusting `wordsUsedCorrectly`
      // unconditionally, a bare single-word turn is forced to contribute
      // nothing here — see `_isBareSingleWordTurn`'s doc comment for why
      // this stays a narrow, deterministic check, not a grammar parser.
      final usedCorrectlyThisTurn = _isBareSingleWordTurn(trimmed)
          ? const <String>{}
          : result.wordsUsedCorrectly
              .map(normalizeWord)
              .where(state.wordIds.contains)
              .toSet();

      // Milestone 7 Phase 2 Stage 8 (3-turn fallback): words the AI itself
      // used this turn — normalized/filtered against the known target
      // words exactly like the student's own usage above, but kept in a
      // separate set throughout. This union feeds ONLY
      // `allWordsUsedCorrectly` (below) so Cowrite can still end when the
      // AI supplies the last remaining word; it must never reach
      // `independentWordsUsedCorrectly`, since AI-assisted usage is not
      // evidence the student mastered the word (`SPEC.md`/`DATA_MODEL.md`
      // §3 rule 2 — mastery requires the student's own independent use).
      final aiUsedWordsThisTurn = result.aiUsedWords
          .map(normalizeWord)
          .where(state.wordIds.contains)
          .toSet();

      final newAllWordsUsedCorrectly = {
        ...state.allWordsUsedCorrectly,
        ...usedCorrectlyThisTurn,
        ...aiUsedWordsThisTurn,
      };

      // Milestone 7 Phase 2 Stage 8 (Issue 4 — end Cowrite immediately):
      // true only when this exact turn is what completes every target
      // word. When that happens purely from the student's own usage (no
      // AI-fallback word contributed this turn), the trailing AI bubble
      // from this same response is suppressed — the conversation should
      // end right on the student's completing message, with no
      // unnecessary extra AI reply. If an AI-fallback word is what
      // completed it (or contributed to completing it), the AI bubble
      // stays, since that bubble is itself the turn that consumed the
      // final target (decision table, Stage 8 investigation/plan).
      final completedByThisTurn = state.wordIds.every(newAllWordsUsedCorrectly.contains);
      final suppressAiBubble = completedByThisTurn && aiUsedWordsThisTurn.isEmpty;

      final updatedTranscript = [
        ...transcriptBeforeSend,
        CowriteTurn(
          sender: CowriteSender.siswa,
          text: trimmed,
          feedback: result.feedback,
          usedSuggestion: usedSuggestion,
        ),
        if (!suppressAiBubble)
          CowriteTurn(
            sender: CowriteSender.ai,
            text: result.aiTurn,
            feedback: null,
            usedSuggestion: false,
          ),
      ];

      state = state.copyWith(
        cowriteTranscript: updatedTranscript,
        allWordsUsedCorrectly: newAllWordsUsedCorrectly,
        independentWordsUsedCorrectly: usedSuggestion
            ? state.independentWordsUsedCorrectly
            : {...state.independentWordsUsedCorrectly, ...usedCorrectlyThisTurn},
        usedSuggestionThisTurn: false,
        pendingSuggestion: null,
        isSendingTurn: false,
      );

      // Milestone 7 Phase 2 Stage 7/8: temporary, non-behavioral
      // diagnostic for an unresolved live observation (Stage 7
      // investigation, Problem A) — a student appeared to use a target
      // word multiple times in Cowrite without the phase ever completing.
      // The app-side mechanism (this file, `allWordsUsedCorrectly`/
      // `allWordsUsed`) is already covered by passing unit tests, so the
      // open question is what the Worker actually returned on those
      // turns — this print gives the next live E2E test that answer
      // directly from the browser console, without guessing at or
      // changing the completion logic itself. Extended in Stage 8 to also
      // show `aiUsedWords`, now that it can also affect completion. Does
      // not log the student id, session id, or any auth/token data.
      debugPrint(
        '[COWRITE DIAGNOSTIC]\n'
        'Student turn: $trimmed\n'
        'Worker wordsUsedCorrectly: ${result.wordsUsedCorrectly}\n'
        'Worker aiUsedWords: ${result.aiUsedWords}\n'
        'Accumulated wordsUsedCorrectly: ${state.allWordsUsedCorrectly}\n'
        'All words used: ${state.allWordsUsed}\n'
        'Feedback: ${result.feedback}',
      );

      final sessionId = state.sessionId;
      if (sessionId != null) {
        try {
          await ref
              .read(learningSessionServiceProvider)
              .saveCowriteTranscript(sessionId: sessionId, transcript: state.cowriteTranscript);
        } catch (error, stackTrace) {
          // The turn itself already succeeded and is reflected in the UI
          // — a save failure here just means this particular turn isn't
          // durable yet. Not surfaced as a blocking error: the *next*
          // successful call re-writes the whole transcript anyway (see
          // `saveCowriteTranscript`'s doc comment), so this self-heals
          // without the student needing to do anything differently.
          debugPrint('LearningFlowController: saveCowriteTranscript failed: $error\n$stackTrace');
        }
      }
    } catch (error, stackTrace) {
      debugPrint('LearningFlowController.sendTurn failed: $error\n$stackTrace');
      state = state.copyWith(
        cowriteTranscript: transcriptBeforeSend,
        isSendingTurn: false,
        turnError: 'Gagal mengirim giliran. Coba lagi.',
      );
    }
  }

  /// Fase 3 → `selesai` (`SPEC.md` §5.3's "✓ Selesai" button, shown once
  /// [LearningFlowState.allWordsUsed] is true). Writes the session's
  /// final fields, then — per Decision 3 — the second (and last) mastery
  /// write, upgrading any word that qualifies.
  ///
  /// Milestone 7 Phase 2 Stage 3: wrapped in try/catch, same pattern as
  /// [generateStory]/[sendTurn] — reuses [LearningFlowState.turnError]
  /// (already rendered on `cowrite_screen.dart`) rather than a new field,
  /// since this is still a Fase 3 write failure shown in the same spot.
  /// On failure, [LearningFlowState.currentPhase] is left untouched
  /// (still `coWrite`), so the student stays on the co-write screen and
  /// can retry by tapping "✓ Selesai" again. Callers must check
  /// [LearningFlowState.turnError] (or that `currentPhase` actually
  /// became `selesai`) after awaiting this before navigating away — this
  /// method no longer throws, so a bare `await` alone is not enough to
  /// detect failure.
  Future<void> completeCowrite() async {
    final sessionId = state.sessionId;
    final clozeTestResult = state.clozeTestResult;
    if (sessionId == null || clozeTestResult == null) return;

    final independentWords = state.independentWordsUsedCorrectly.toList();
    state = state.copyWith(turnError: null);

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

      state = state.copyWith(currentPhase: LearningSessionPhase.selesai);
    } catch (error, stackTrace) {
      debugPrint('LearningFlowController.completeCowrite failed: $error\n$stackTrace');
      state = state.copyWith(turnError: 'Gagal menyelesaikan sesi. Coba lagi.');
    }
  }

  List<Map<String, String>> _transcriptPayload() {
    return [
      for (final turn in state.cowriteTranscript) {'sender': turn.sender, 'text': turn.text},
    ];
  }
}

/// Client-side safety guard for bare single-word Cowrite turns.
/// This is intentionally narrow: it does not attempt grammar checking.
/// A single word is excluded from mastery/completion tracking, while
/// the student's message and Worker feedback are still preserved.
bool _isBareSingleWordTurn(String text) {
  final stripped = text.replaceAll(_terminalPunctuationPattern, '').trim();

  if (stripped.isEmpty) return false;

  return !stripped.contains(RegExp(r'\s'));
}

final RegExp _terminalPunctuationPattern = RegExp(r'''^[.,!?;:"']+|[.,!?;:"']+$''');
