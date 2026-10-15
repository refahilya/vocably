// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Source of randomness for the Co-Write fallback's word selection
/// (`selectFallbackWord`) — a provider so tests can inject a seeded or
/// scripted [Random] and assert exactly which word was forced.

@ProviderFor(cowriteFallbackRandom)
final cowriteFallbackRandomProvider = CowriteFallbackRandomProvider._();

/// Source of randomness for the Co-Write fallback's word selection
/// (`selectFallbackWord`) — a provider so tests can inject a seeded or
/// scripted [Random] and assert exactly which word was forced.

final class CowriteFallbackRandomProvider
    extends $FunctionalProvider<Random, Random, Random>
    with $Provider<Random> {
  /// Source of randomness for the Co-Write fallback's word selection
  /// (`selectFallbackWord`) — a provider so tests can inject a seeded or
  /// scripted [Random] and assert exactly which word was forced.
  CowriteFallbackRandomProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cowriteFallbackRandomProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cowriteFallbackRandomHash();

  @$internal
  @override
  $ProviderElement<Random> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Random create(Ref ref) {
    return cowriteFallbackRandom(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Random value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Random>(value),
    );
  }
}

String _$cowriteFallbackRandomHash() =>
    r'5ea7c4a3621673b3571932167bf7096b3b502e23';

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
    r'0eda8167c03d4bdeaf1bc613f47a3df407ffe5f6';

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
