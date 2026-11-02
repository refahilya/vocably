import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/placement_attempt.dart';
import '../models/placement_instrument.dart';
import '../models/placement_status.dart';
import '../services/placement_service.dart';
import '../services/research_assessment_service.dart';
import 'auth_providers.dart';
import 'research_assessment_providers.dart';

part 'placement_test_providers.g.dart';

/// Flips `users.placementTestPrompted` to `true` the moment the one-time
/// automatic offer (`SPEC.md` §3.1) is shown, whatever the student picks.
///
/// Kept alive per student: the write's local snapshot takes the offer off
/// screen before the server answers, and a refusal rolls that snapshot back
/// and brings the offer back. The failure has to outlive the offer screen in
/// between so the returning offer can say why it is there again.
@Riverpod(keepAlive: true)
class PlacementTestPromptController extends _$PlacementTestPromptController {
  @override
  FutureOr<void> build(String uid) {}

  Future<void> markPrompted() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(userServiceProvider).markPlacementTestPrompted(uid);
    });
    if (ref.mounted) state = result;
  }
}

@riverpod
PlacementService placementService(Ref ref) => PlacementService();

/// Why an action failed, for the UI to explain.
enum PlacementActionError {
  /// No connection / timeout: safe to try again.
  network,

  /// The rules refused it and re-reading didn't explain why. Only the
  /// researcher/supervisor can resolve it.
  refused,
}

sealed class PlacementTestState {
  const PlacementTestState();
}

class PlacementTestLoading extends PlacementTestState {
  const PlacementTestLoading();
}

class PlacementTestLoadFailed extends PlacementTestState {
  const PlacementTestLoadFailed();
}

/// The bank or stored data contradicts the data model: never guessed at.
class PlacementTestInvalid extends PlacementTestState {
  const PlacementTestInvalid();
}

class PlacementTestBlocked extends PlacementTestState {
  const PlacementTestBlocked(this.reason, {this.lastResult});

  final PlacementBlock reason;
  final PlacementAttemptRecord? lastResult;
}

/// Instructions + "Mulai" for a new attempt.
class PlacementTestReady extends PlacementTestState {
  const PlacementTestReady(this.context, this.attemptNumber, {this.starting = false, this.error});

  final PlacementContext context;
  final int attemptNumber;
  final bool starting;
  final PlacementActionError? error;
}

/// An unfinished attempt whose window is closed: answers are kept.
class PlacementTestPaused extends PlacementTestState {
  const PlacementTestPaused(this.context);

  final PlacementContext context;
}

/// Answering one item per screen, or (with [reviewing]) the summary before
/// submitting. [attempt] always holds the server's answers.
class PlacementTestAnswering extends PlacementTestState {
  const PlacementTestAnswering({
    required this.attempt,
    required this.items,
    required this.index,
    this.showIntro = false,
    this.reviewing = false,
    this.savingItemId,
    this.submitting = false,
    this.error,
  });

  final PlacementAttemptRecord attempt;

  /// Items in the attempt's stored display order.
  final List<PlacementItem> items;
  final int index;
  final bool showIntro;
  final bool reviewing;
  final String? savingItemId;
  final bool submitting;
  final PlacementActionError? error;

  PlacementItem get currentItem => items[index];
  bool get busy => savingItemId != null || submitting;

  /// 1-based numbers of unanswered items, in display order.
  List<int> get unansweredNumbers => [
    for (var i = 0; i < items.length; i++)
      if (!attempt.answers.containsKey(items[i].id)) i + 1,
  ];

  PlacementTestAnswering copyWith({
    PlacementAttemptRecord? attempt,
    int? index,
    bool? showIntro,
    bool? reviewing,
    String? savingItemId,
    bool clearSaving = false,
    bool? submitting,
    PlacementActionError? error,
    bool clearError = false,
  }) => PlacementTestAnswering(
    attempt: attempt ?? this.attempt,
    items: items,
    index: index ?? this.index,
    showIntro: showIntro ?? this.showIntro,
    reviewing: reviewing ?? this.reviewing,
    savingItemId: clearSaving ? null : (savingItemId ?? this.savingItemId),
    submitting: submitting ?? this.submitting,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Answers are frozen on the server; the result is being processed.
class PlacementTestScoring extends PlacementTestState {
  const PlacementTestScoring({this.error});

  final PlacementActionError? error;
}

class PlacementTestResult extends PlacementTestState {
  const PlacementTestResult(
    this.attempt, {
    this.justFinished = false,
    this.nextLearningAttempt,
    this.retakeAvailableAt,
  });

  final PlacementAttemptRecord attempt;
  final bool justFinished;
  final int? nextLearningAttempt;
  final DateTime? retakeAvailableAt;
}

/// Drives the Placement Test for [uid] (`SPEC.md` §3.1, `DATA_MODEL.md` §6).
///
/// The server is the only source of truth: after any failed or timed-out
/// write the attempt is re-read and the state rebuilt from what is stored.
/// "Terkirim" is shown only after the server holds `submitted`; the result
/// only after the server holds `scored`. Lifecycle signals are recorded and
/// never acted on.
@riverpod
class PlacementTestController extends _$PlacementTestController {
  PlacementInstrument? _instrument;
  bool _busy = false;

  PlacementService get _service => ref.read(placementServiceProvider);

  @override
  PlacementTestState build(String uid) {
    Future.microtask(_load);
    return const PlacementTestLoading();
  }

  void _set(PlacementTestState next) {
    if (ref.mounted) state = next;
  }

  Future<void> reload() async {
    _set(const PlacementTestLoading());
    await _load();
  }

  Future<void> _load() async {
    try {
      _instrument ??= await _service.loadInstrument();
      final config = await _service.fetchConfig();
      final participant = await _service.fetchParticipant(uid);
      final study = await _service.fetchStudy();
      final attempts = await _service.fetchOwnAttempts(uid);
      final status = resolvePlacementStatus(
        config: config,
        participant: participant,
        study: study,
        attempts: attempts,
        now: DateTime.now(),
      );
      switch (status) {
        case PlacementBlocked(:final reason, :final lastResult):
          _set(PlacementTestBlocked(reason, lastResult: lastResult));
        case PlacementCanStart(:final context, :final attemptNumber):
          _set(PlacementTestReady(context, attemptNumber));
        case PlacementResumable(:final attempt, :final open):
          if (open) {
            _enter(attempt, showIntro: true);
          } else {
            _set(PlacementTestPaused(attempt.context));
          }
        case PlacementAwaitingScore(:final attempt):
          await _score(attempt);
        case PlacementHasResult(:final attempt, :final nextLearningAttempt, :final retakeAvailableAt):
          _set(PlacementTestResult(attempt, nextLearningAttempt: nextLearningAttempt, retakeAvailableAt: retakeAvailableAt));
      }
    } on PlacementInstrumentException {
      _set(const PlacementTestInvalid());
    } on ResearchServiceException catch (error) {
      _set(error.kind == ResearchFailureKind.invalidData ? const PlacementTestInvalid() : const PlacementTestLoadFailed());
    } catch (_) {
      _set(const PlacementTestLoadFailed());
    }
  }

  void _enter(PlacementAttemptRecord attempt, {bool showIntro = false}) {
    final instrument = _instrument!;
    final items = <PlacementItem>[];
    for (final id in attempt.itemOrder) {
      final item = instrument.itemById(id);
      if (item == null || attempt.instrumentVersion != instrument.version) {
        _set(const PlacementTestInvalid());
        return;
      }
      items.add(item);
    }
    final first = attempt.firstUnansweredIndex;
    _set(PlacementTestAnswering(
      attempt: attempt,
      items: items,
      index: first ?? items.length - 1,
      reviewing: first == null,
      showIntro: showIntro,
    ));
  }

  /// Creates the attempt with a fresh per-band shuffle, then shows the
  /// **stored** order (a create racing another tab can't show another one).
  ///
  /// The re-read uses the own-attempts query: the rules refuse a `get` on a
  /// document that doesn't exist, so after a refused create [fetchAttempt]
  /// can only fail, which would read as a connection problem.
  Future<void> start() async {
    final current = state;
    if (current is! PlacementTestReady || current.starting || _busy) return;
    _busy = true;
    _set(PlacementTestReady(current.context, current.attemptNumber, starting: true));
    final id = PlacementAttemptRecord.idFor(uid, current.context, current.attemptNumber);
    ResearchServiceException? writeError;
    try {
      await _service.createAttempt(
        studentId: uid,
        context: current.context,
        attemptNumber: current.attemptNumber,
        itemOrder: PlacementAttemptRecord.buildItemOrder(_instrument!, ref.read(researchAssessmentRandomProvider)),
      );
    } on ResearchServiceException catch (error) {
      writeError = error;
    }
    final refused = writeError?.kind == ResearchFailureKind.permissionDenied;
    try {
      final own = await _service.fetchOwnAttempts(uid);
      final stored = own
          .where((a) => a.id == id && a.context == current.context && a.attemptNumber == current.attemptNumber)
          .firstOrNull;
      if (stored != null && stored.status == PlacementAttemptStatus.inProgress) {
        _enter(stored);
      } else if (refused || stored != null) {
        await _load();
        // The re-read decides with the device clock, the rules with the
        // server's: never leave a refused start looking like a dead button.
        final after = ref.mounted ? state : null;
        if (refused && after is PlacementTestReady) {
          _set(PlacementTestReady(after.context, after.attemptNumber, error: PlacementActionError.refused));
        }
      } else {
        _set(PlacementTestReady(current.context, current.attemptNumber, error: PlacementActionError.network));
      }
    } on ResearchServiceException {
      _set(PlacementTestReady(current.context, current.attemptNumber, error: PlacementActionError.network));
    } finally {
      _busy = false;
    }
  }

  void dismissIntro() {
    final current = state;
    if (current is PlacementTestAnswering) _set(current.copyWith(showIntro: false));
  }

  /// Saves the choice immediately (spec §4.2: answers are saved on every
  /// selection); answers may change until submission.
  Future<void> select(String answer) async {
    final current = state;
    if (current is! PlacementTestAnswering || current.busy || current.reviewing || _busy) return;
    if (!kPlacementAnswerIds.contains(answer)) return;
    final item = current.currentItem;
    if (current.attempt.answers[item.id] == answer) return;
    _busy = true;
    _set(current.copyWith(savingItemId: item.id, clearError: true));
    try {
      await _service.saveAnswer(attemptId: current.attempt.id, itemId: item.id, answer: answer);
      final latest = state;
      if (latest is PlacementTestAnswering) {
        _set(latest.copyWith(
          attempt: latest.attempt.copyWith(answers: {...latest.attempt.answers, item.id: answer}),
          clearSaving: true,
        ));
      }
    } on ResearchServiceException catch (error) {
      await _afterFailedWrite(current, error, itemId: item.id, answer: answer);
    } finally {
      _busy = false;
    }
  }

  /// Re-reads the attempt after a failed write and rebuilds from the server.
  /// A lost acknowledgement (the answer is in fact stored) is not an error.
  Future<void> _afterFailedWrite(
    PlacementTestAnswering previous,
    ResearchServiceException error, {
    String? itemId,
    String? answer,
  }) async {
    try {
      final stored = await _service.fetchAttempt(previous.attempt.id);
      if (stored == null || stored.status != PlacementAttemptStatus.inProgress || error.kind == ResearchFailureKind.permissionDenied) {
        await _load();
        return;
      }
      final landed = itemId != null && stored.answers[itemId] == answer;
      _set(previous.copyWith(
        attempt: stored,
        clearSaving: true,
        submitting: false,
        error: landed ? null : PlacementActionError.network,
        clearError: landed,
      ));
    } on ResearchServiceException {
      _set(previous.copyWith(clearSaving: true, submitting: false, error: PlacementActionError.network));
    }
  }

  void goTo(int index) {
    final current = state;
    if (current is! PlacementTestAnswering || current.busy) return;
    if (index < 0 || index >= current.items.length) return;
    _set(current.copyWith(index: index, reviewing: false, clearError: true));
  }

  void next() {
    final current = state;
    if (current is! PlacementTestAnswering || current.busy) return;
    if (current.index == current.items.length - 1) {
      _set(current.copyWith(reviewing: true, clearError: true));
    } else {
      _set(current.copyWith(index: current.index + 1, clearError: true));
    }
  }

  void previous() {
    final current = state;
    if (current is PlacementTestAnswering) goTo(current.index - 1);
  }

  void openSummary() {
    final current = state;
    if (current is PlacementTestAnswering && !current.busy) _set(current.copyWith(reviewing: true, clearError: true));
  }

  /// Submits (after the UI's confirmation). Shows success only once the
  /// server holds `submitted`, then scores.
  Future<void> submit() async {
    final current = state;
    if (current is! PlacementTestAnswering || current.busy || _busy) return;
    if (current.unansweredNumbers.isNotEmpty) return;
    _busy = true;
    _set(current.copyWith(submitting: true, clearError: true));
    ResearchServiceException? writeError;
    try {
      await _service.submit(current.attempt.id);
    } on ResearchServiceException catch (error) {
      writeError = error;
    }
    try {
      final stored = await _service.fetchAttempt(current.attempt.id);
      if (stored != null && stored.status == PlacementAttemptStatus.submitted) {
        await _score(stored);
      } else if (writeError != null) {
        await _afterFailedWrite(current, writeError);
      } else {
        await _load();
      }
    } on ResearchServiceException {
      _set(current.copyWith(submitting: false, error: PlacementActionError.network));
    } finally {
      _busy = false;
    }
  }

  Future<void> _score(PlacementAttemptRecord attempt) async {
    _set(const PlacementTestScoring());
    PlacementActionError? error;
    try {
      await _service.score(attempt);
    } on ResearchServiceException {
      error = PlacementActionError.network;
    }
    try {
      final stored = await _service.fetchAttempt(attempt.id);
      if (stored != null && stored.status == PlacementAttemptStatus.scored) {
        _set(PlacementTestResult(stored, justFinished: true));
        return;
      }
      if (stored != null && stored.status == PlacementAttemptStatus.voided) {
        await _load();
        return;
      }
      _set(PlacementTestScoring(error: error ?? PlacementActionError.refused));
    } on ResearchServiceException {
      _set(const PlacementTestScoring(error: PlacementActionError.network));
    }
  }

  /// Retries scoring a submitted attempt (idempotent: it is scored once).
  Future<void> retryScoring() async {
    if (_busy || state is! PlacementTestScoring) return;
    _busy = true;
    try {
      final attempts = await _service.fetchOwnAttempts(uid);
      final submitted = attempts.where((a) => a.status == PlacementAttemptStatus.submitted).toList();
      if (submitted.isEmpty) {
        await _load();
      } else {
        await _score(submitted.first);
      }
    } on ResearchServiceException {
      _set(const PlacementTestScoring(error: PlacementActionError.network));
    } finally {
      _busy = false;
    }
  }

  /// Starts a learning-only retake from the result screen, when open.
  void startRetake() {
    final current = state;
    if (current is PlacementTestResult && current.nextLearningAttempt != null) {
      _set(PlacementTestReady(PlacementContext.learning, current.nextLearningAttempt!));
    }
  }

  /// "App hidden" signal from `AppLifecycleListener`: recorded on the
  /// attempt (best effort), never acted on and never shown to the student.
  Future<void> recordHidden() async {
    final current = state;
    if (current is! PlacementTestAnswering) return;
    final next = current.attempt.tabSwitchCount + 1;
    try {
      await _service.recordHidden(current.attempt.id, next);
      final latest = state;
      if (latest is PlacementTestAnswering && latest.attempt.id == current.attempt.id) {
        _set(latest.copyWith(attempt: latest.attempt.copyWith(tabSwitchCount: next)));
      }
    } on ResearchServiceException {
      // Best effort: a lost signal is acceptable; it never affects the test.
    }
  }
}
