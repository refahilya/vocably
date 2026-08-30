// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(LearningFlowController)
final learningFlowControllerProvider = LearningFlowControllerProvider._();

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
final class LearningFlowControllerProvider
    extends $NotifierProvider<LearningFlowController, LearningFlowState> {
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
  LearningFlowControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'learningFlowControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$learningFlowControllerHash();

  @$internal
  @override
  LearningFlowController create() => LearningFlowController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LearningFlowState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LearningFlowState>(value),
    );
  }
}

String _$learningFlowControllerHash() =>
    r'40525e5f815eb472c20fb7e382e7f66db8f773d7';

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

abstract class _$LearningFlowController extends $Notifier<LearningFlowState> {
  LearningFlowState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LearningFlowState, LearningFlowState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LearningFlowState, LearningFlowState>,
              LearningFlowState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
