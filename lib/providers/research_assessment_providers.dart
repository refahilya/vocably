import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/research_attempt.dart';
import '../models/research_attempt_plan.dart';
import '../models/research_instrument.dart';
import '../models/research_participant.dart';
import '../services/research_assessment_service.dart';
import '../services/research_instrument_service.dart';
import '../utils/research_attempt_planner.dart';

part 'research_assessment_providers.g.dart';

@riverpod
ResearchAssessmentService researchAssessmentService(Ref ref) =>
    ResearchAssessmentService();

@Riverpod(keepAlive: true)
ResearchInstrumentService researchInstrumentService(Ref ref) =>
    ResearchInstrumentService();

/// The validated app-safe bank for [version], loaded once per app run.
@Riverpod(keepAlive: true)
Future<ResearchInstrument> researchInstrument(Ref ref, String version) =>
    ref.watch(researchInstrumentServiceProvider).load(version);

/// Randomness for new attempt plans: `Random.secure()` in the app; a
/// provider so tests can inject a seeded [Random].
@Riverpod(keepAlive: true)
Random researchAssessmentRandom(Ref ref) => Random.secure();

/// Dashboard status of one stage for [uid] — always from the server, never
/// a placeholder constant.
@riverpod
Future<ResearchStageKind> researchStageStatus(
  Ref ref,
  String uid,
  ResearchStage stage,
) async {
  final snapshot = await ref
      .watch(researchAssessmentServiceProvider)
      .loadStage(uid, stage);
  return snapshot.kind;
}

/// Why an action could not be completed, for the UI to explain.
enum ResearchActionError {
  /// No connection / timeout: safe to try again.
  network,

  /// The rules refused it and re-reading didn't explain why (for example,
  /// bank data not seeded). Only the researcher can resolve it.
  refused,
}

sealed class ResearchAssessmentState {
  const ResearchAssessmentState();
}

class ResearchAssessmentLoading extends ResearchAssessmentState {
  const ResearchAssessmentLoading();
}

/// Loading failed (network or unexpected error); [retry] is safe.
class ResearchAssessmentLoadFailed extends ResearchAssessmentState {
  const ResearchAssessmentLoadFailed();
}

/// Not a participant, not authorized, posttest locked, or voided — the
/// student can't do anything here until the researcher acts.
class ResearchAssessmentUnavailable extends ResearchAssessmentState {
  const ResearchAssessmentUnavailable(this.kind);

  final ResearchStageKind kind;
}

/// Stored data contradicts the research data model; resuming would be
/// unsafe, so the student is asked to contact the researcher.
class ResearchAssessmentInvalid extends ResearchAssessmentState {
  const ResearchAssessmentInvalid();
}

/// Authorized and not started: show the instructions and "Mulai".
class ResearchAssessmentReady extends ResearchAssessmentState {
  const ResearchAssessmentReady({this.starting = false, this.error});

  final bool starting;
  final ResearchActionError? error;
}

/// Answering items, one per screen, in the attempt's stored order.
class ResearchAssessmentInProgress extends ResearchAssessmentState {
  const ResearchAssessmentInProgress({
    required this.plan,
    required this.currentIndex,
    this.showIntro = false,
    this.selectedOptionId,
    this.saving = false,
    this.selectionLocked = false,
    this.error,
  });

  final ResearchAttemptPlan plan;

  /// Index into [ResearchAttemptPlan.items] of the item on screen: always
  /// the first item without a saved answer.
  final int currentIndex;

  /// A resumed attempt shows the instructions again before continuing.
  final bool showIntro;
  final String? selectedOptionId;
  final bool saving;

  /// The current choice has been submitted at least once and can no longer
  /// be changed (see [ResearchAssessmentController.select]).
  final bool selectionLocked;
  final ResearchActionError? error;

  PlannedResearchItem get currentItem => plan.items[currentIndex];
  bool get isLastItem => currentIndex == plan.items.length - 1;

  ResearchAssessmentInProgress copyWith({
    bool? showIntro,
    String? selectedOptionId,
    bool? saving,
    bool? selectionLocked,
    ResearchActionError? error,
    bool clearError = false,
  }) => ResearchAssessmentInProgress(
    plan: plan,
    currentIndex: currentIndex,
    showIntro: showIntro ?? this.showIntro,
    selectedOptionId: selectedOptionId ?? this.selectedOptionId,
    saving: saving ?? this.saving,
    selectionLocked: selectionLocked ?? this.selectionLocked,
    error: clearError ? null : (error ?? this.error),
  );
}

/// All 20 answers are saved; marking the attempt completed is in progress
/// or failed ([error]) and can be retried.
class ResearchAssessmentCompleting extends ResearchAssessmentState {
  const ResearchAssessmentCompleting({this.error});

  final ResearchActionError? error;
}

class ResearchAssessmentCompleted extends ResearchAssessmentState {
  const ResearchAssessmentCompleted();
}

/// Drives one pretest or posttest attempt for [uid] (`SPEC.md` §3.7,
/// `DATA_MODEL.md` §6b).
///
/// The server is the only source of truth. After every write — whether it
/// succeeded, failed or timed out — the attempt is re-read from the server
/// and the state is rebuilt from what is actually stored:
/// - a new attempt is shown in the **stored** order, never the local plan,
///   so a create that raced another tab can't show a different order;
/// - an answer counts as saved only when the server has it; a retry after a
///   lost acknowledgement is refused by the rules (answers are write-once)
///   and the re-read shows the answer is already there;
/// - the attempt is completed only after the server holds all 20 answers.
/// No scores or correctness information exist anywhere in this flow.
@riverpod
class ResearchAssessmentController extends _$ResearchAssessmentController {
  ResearchParticipant? _participant;
  String? _attemptId;
  ResearchInstrument? _instrument;
  bool _busy = false;

  ResearchAssessmentService get _service =>
      ref.read(researchAssessmentServiceProvider);

  @override
  ResearchAssessmentState build(String uid, ResearchStage stage) {
    Future.microtask(_load);
    return const ResearchAssessmentLoading();
  }

  void _set(ResearchAssessmentState next) {
    if (ref.mounted) state = next;
  }

  /// Reloads everything from the server (also the retry for a failed load).
  Future<void> reload() async {
    _set(const ResearchAssessmentLoading());
    await _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await _service.loadStage(uid, stage);
      _participant = snapshot.participant;
      _attemptId = snapshot.attemptId;
      switch (snapshot.kind) {
        case ResearchStageKind.notEnrolled ||
            ResearchStageKind.notAuthorized ||
            ResearchStageKind.locked ||
            ResearchStageKind.voided:
          _set(ResearchAssessmentUnavailable(snapshot.kind));
        case ResearchStageKind.invalid:
          _set(const ResearchAssessmentInvalid());
        case ResearchStageKind.completed:
          _set(const ResearchAssessmentCompleted());
        case ResearchStageKind.notStarted:
          await _loadInstrument();
          _set(const ResearchAssessmentReady());
        case ResearchStageKind.inProgress:
          await _loadInstrument();
          await _enter(snapshot.attempt!, showIntro: true);
      }
    } on ResearchServiceException catch (error) {
      _set(
        error.kind == ResearchFailureKind.invalidData
            ? const ResearchAssessmentInvalid()
            : const ResearchAssessmentLoadFailed(),
      );
    } on ResearchInstrumentException {
      _set(const ResearchAssessmentInvalid());
    } catch (_) {
      _set(const ResearchAssessmentLoadFailed());
    }
  }

  Future<void> _loadInstrument() async {
    _instrument = await ref.read(
      researchInstrumentProvider(
        _participant!.assignment.instrumentVersion,
      ).future,
    );
  }

  /// Rebuilds the state from a stored attempt: its own order, its saved
  /// answers, and the first item still unanswered.
  Future<void> _enter(
    ResearchAttemptRecord attempt, {
    bool showIntro = false,
  }) async {
    switch (attempt.status) {
      case ResearchAttemptStatus.completed:
        _set(const ResearchAssessmentCompleted());
        return;
      case ResearchAttemptStatus.voided:
        _set(const ResearchAssessmentUnavailable(ResearchStageKind.voided));
        return;
      case ResearchAttemptStatus.inProgress:
        break;
    }
    final plan = ResearchAttemptPlan.fromOrder(
      instrument: _instrument!,
      assignment: _participant!.assignment,
      itemOrder: attempt.itemOrder,
      optionOrder: attempt.optionOrder,
    );
    final byId = {for (final item in plan.items) item.itemId: item};
    for (final entry in attempt.responses.entries) {
      final item = byId[entry.key];
      if (item == null || !entry.value.matches(item)) {
        throw ResearchInstrumentException(
          'saved answer for ${entry.key} does not match the attempt order',
        );
      }
    }
    final index = plan.firstUnansweredIndex(attempt.responses.keys);
    if (index == null) {
      await _complete();
      return;
    }
    _set(
      ResearchAssessmentInProgress(
        plan: plan,
        currentIndex: index,
        showIntro: showIntro,
      ),
    );
  }

  /// Creates the attempt with a fresh `Random.secure()` plan, then shows
  /// whatever order the server actually stored.
  Future<void> start() async {
    if (state is! ResearchAssessmentReady || _busy) return;
    _busy = true;
    _set(const ResearchAssessmentReady(starting: true));
    try {
      final plan = planResearchAttempt(
        instrument: _instrument!,
        assignment: _participant!.assignment,
        random: ref.read(researchAssessmentRandomProvider),
      );
      ResearchServiceException? writeError;
      try {
        await _service.createAttempt(
          studentId: uid,
          stage: stage,
          attemptNumber: _participant!.authorizedAttempt(stage),
          plan: plan,
        );
      } on ResearchServiceException catch (error) {
        writeError = error;
      }
      final ResearchAttemptRecord? stored;
      try {
        stored = await _service.fetchAttempt(_attemptId!);
      } on ResearchServiceException {
        _set(const ResearchAssessmentReady(error: ResearchActionError.network));
        return;
      }
      if (stored?.status == ResearchAttemptStatus.voided) {
        // Started and voided elsewhere meanwhile; a retake may be authorized.
        await _load();
      } else if (stored != null) {
        await _enter(stored);
      } else if (writeError?.kind == ResearchFailureKind.permissionDenied) {
        // The authorization may have changed since loading (e.g. a retake);
        // re-resolve, and only report a refusal if nothing changed.
        final previous = _attemptId;
        await _load();
        if (state is ResearchAssessmentReady && _attemptId == previous) {
          _set(
            const ResearchAssessmentReady(error: ResearchActionError.refused),
          );
        }
      } else {
        _set(const ResearchAssessmentReady(error: ResearchActionError.network));
      }
    } on ResearchInstrumentException {
      _set(const ResearchAssessmentInvalid());
    } catch (_) {
      _set(const ResearchAssessmentReady(error: ResearchActionError.network));
    } finally {
      _busy = false;
    }
  }

  /// Leaves the instructions shown before a resumed attempt.
  void continueFromIntro() {
    final current = state;
    if (current is ResearchAssessmentInProgress && current.showIntro) {
      _set(current.copyWith(showIntro: false));
    }
  }

  /// Local choice only; nothing is saved until [submit]. Once a choice has
  /// been submitted for this item it is locked, even if the save could not
  /// be confirmed: the write may still reach the server later and would then
  /// be the stored answer, so offering a different choice would be
  /// misleading.
  void select(String optionId) {
    final current = state;
    if (current is! ResearchAssessmentInProgress ||
        current.saving ||
        current.selectionLocked ||
        current.showIntro) {
      return;
    }
    if (!current.currentItem.displayOptions.any((o) => o.id == optionId)) {
      return;
    }
    _set(current.copyWith(selectedOptionId: optionId, clearError: true));
  }

  /// Saves the selected answer and moves on only once the server holds an
  /// answer for this item. Safe to call again after any failure: a
  /// duplicate is refused by the rules and resolved by the re-read.
  Future<void> submit() async {
    final current = state;
    if (current is! ResearchAssessmentInProgress ||
        current.saving ||
        current.showIntro ||
        current.selectedOptionId == null ||
        _busy) {
      return;
    }
    _busy = true;
    _set(
      current.copyWith(saving: true, selectionLocked: true, clearError: true),
    );
    try {
      final item = current.currentItem;
      final response = ResearchResponse.forPlannedItem(
        item,
        current.selectedOptionId!,
      );
      ResearchServiceException? writeError;
      try {
        await _service.saveAnswer(
          attemptId: _attemptId!,
          itemId: item.itemId,
          response: response,
        );
      } on ResearchServiceException catch (error) {
        writeError = error;
      }

      final ResearchAttemptRecord? stored;
      try {
        stored = await _service.fetchAttempt(_attemptId!);
      } on ResearchServiceException catch (error) {
        if (error.kind == ResearchFailureKind.invalidData) rethrow;
        _set(
          current.copyWith(
            saving: false,
            selectionLocked: true,
            error: ResearchActionError.network,
          ),
        );
        return;
      }
      if (stored == null) {
        _set(const ResearchAssessmentInvalid());
      } else if (stored.status == ResearchAttemptStatus.voided) {
        // Voided by the researcher mid-attempt; a retake may already be
        // authorized, so re-resolve the stage from the server.
        await _load();
      } else if (stored.status != ResearchAttemptStatus.inProgress ||
          stored.responses.containsKey(item.itemId)) {
        // Saved now, or already saved earlier (a lost acknowledgement or
        // another tab) — either way the stored answer stands.
        await _enter(stored);
      } else if (writeError?.kind == ResearchFailureKind.permissionDenied) {
        // Refused and not saved: the authorization changed under us
        // (for example, a retake was authorized). Start over from the server.
        await _load();
      } else {
        _set(
          current.copyWith(
            saving: false,
            selectionLocked: true,
            error: ResearchActionError.network,
          ),
        );
      }
    } on ResearchServiceException {
      _set(const ResearchAssessmentInvalid());
    } on ResearchInstrumentException {
      _set(const ResearchAssessmentInvalid());
    } catch (_) {
      // Unexpected error: never leave the spinner up; retrying is safe.
      _set(
        current.copyWith(
          saving: false,
          selectionLocked: true,
          error: ResearchActionError.network,
        ),
      );
    } finally {
      _busy = false;
    }
  }

  /// Retries marking a fully answered attempt completed.
  Future<void> retryCompletion() async {
    if (state is! ResearchAssessmentCompleting || _busy) return;
    _busy = true;
    try {
      await _complete();
    } on ResearchInstrumentException {
      _set(const ResearchAssessmentInvalid());
    } catch (_) {
      _set(
        const ResearchAssessmentCompleting(error: ResearchActionError.network),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _complete() async {
    _set(const ResearchAssessmentCompleting());
    ResearchServiceException? writeError;
    try {
      await _service.completeAttempt(_attemptId!);
    } on ResearchServiceException catch (error) {
      writeError = error;
    }
    final ResearchAttemptRecord? stored;
    try {
      stored = await _service.fetchAttempt(_attemptId!);
    } on ResearchServiceException catch (error) {
      _set(
        error.kind == ResearchFailureKind.invalidData
            ? const ResearchAssessmentInvalid()
            : const ResearchAssessmentCompleting(
                error: ResearchActionError.network,
              ),
      );
      return;
    }
    switch (stored?.status) {
      case ResearchAttemptStatus.completed:
        _set(const ResearchAssessmentCompleted());
      case ResearchAttemptStatus.voided:
        await _load();
      case ResearchAttemptStatus.inProgress:
        if (writeError?.kind == ResearchFailureKind.permissionDenied) {
          if (stored!.allItemsAnswered) {
            _set(
              const ResearchAssessmentCompleting(
                error: ResearchActionError.refused,
              ),
            );
          } else {
            await _load();
          }
        } else {
          _set(
            const ResearchAssessmentCompleting(
              error: ResearchActionError.network,
            ),
          );
        }
      case null:
        _set(const ResearchAssessmentInvalid());
    }
  }
}
