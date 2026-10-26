// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'research_assessment_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(researchAssessmentService)
final researchAssessmentServiceProvider = ResearchAssessmentServiceProvider._();

final class ResearchAssessmentServiceProvider
    extends
        $FunctionalProvider<
          ResearchAssessmentService,
          ResearchAssessmentService,
          ResearchAssessmentService
        >
    with $Provider<ResearchAssessmentService> {
  ResearchAssessmentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'researchAssessmentServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$researchAssessmentServiceHash();

  @$internal
  @override
  $ProviderElement<ResearchAssessmentService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ResearchAssessmentService create(Ref ref) {
    return researchAssessmentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResearchAssessmentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResearchAssessmentService>(value),
    );
  }
}

String _$researchAssessmentServiceHash() =>
    r'0dfd8998232ace17f11a52cec83ceb030e7fb808';

@ProviderFor(researchInstrumentService)
final researchInstrumentServiceProvider = ResearchInstrumentServiceProvider._();

final class ResearchInstrumentServiceProvider
    extends
        $FunctionalProvider<
          ResearchInstrumentService,
          ResearchInstrumentService,
          ResearchInstrumentService
        >
    with $Provider<ResearchInstrumentService> {
  ResearchInstrumentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'researchInstrumentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$researchInstrumentServiceHash();

  @$internal
  @override
  $ProviderElement<ResearchInstrumentService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ResearchInstrumentService create(Ref ref) {
    return researchInstrumentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResearchInstrumentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResearchInstrumentService>(value),
    );
  }
}

String _$researchInstrumentServiceHash() =>
    r'731a9a56add12e83863b40d4c6b9609cb66cfb04';

/// The validated app-safe bank for [version], loaded once per app run.

@ProviderFor(researchInstrument)
final researchInstrumentProvider = ResearchInstrumentFamily._();

/// The validated app-safe bank for [version], loaded once per app run.

final class ResearchInstrumentProvider
    extends
        $FunctionalProvider<
          AsyncValue<ResearchInstrument>,
          ResearchInstrument,
          FutureOr<ResearchInstrument>
        >
    with
        $FutureModifier<ResearchInstrument>,
        $FutureProvider<ResearchInstrument> {
  /// The validated app-safe bank for [version], loaded once per app run.
  ResearchInstrumentProvider._({
    required ResearchInstrumentFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'researchInstrumentProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$researchInstrumentHash();

  @override
  String toString() {
    return r'researchInstrumentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ResearchInstrument> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ResearchInstrument> create(Ref ref) {
    final argument = this.argument as String;
    return researchInstrument(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ResearchInstrumentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$researchInstrumentHash() =>
    r'a8275a20819e3cc0fe1aa93c1a037137d516042c';

/// The validated app-safe bank for [version], loaded once per app run.

final class ResearchInstrumentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ResearchInstrument>, String> {
  ResearchInstrumentFamily._()
    : super(
        retry: null,
        name: r'researchInstrumentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The validated app-safe bank for [version], loaded once per app run.

  ResearchInstrumentProvider call(String version) =>
      ResearchInstrumentProvider._(argument: version, from: this);

  @override
  String toString() => r'researchInstrumentProvider';
}

/// Randomness for new attempt plans: `Random.secure()` in the app; a
/// provider so tests can inject a seeded [Random].

@ProviderFor(researchAssessmentRandom)
final researchAssessmentRandomProvider = ResearchAssessmentRandomProvider._();

/// Randomness for new attempt plans: `Random.secure()` in the app; a
/// provider so tests can inject a seeded [Random].

final class ResearchAssessmentRandomProvider
    extends $FunctionalProvider<Random, Random, Random>
    with $Provider<Random> {
  /// Randomness for new attempt plans: `Random.secure()` in the app; a
  /// provider so tests can inject a seeded [Random].
  ResearchAssessmentRandomProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'researchAssessmentRandomProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$researchAssessmentRandomHash();

  @$internal
  @override
  $ProviderElement<Random> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Random create(Ref ref) {
    return researchAssessmentRandom(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Random value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Random>(value),
    );
  }
}

String _$researchAssessmentRandomHash() =>
    r'066a9ed2d06eb56abb3794b50840a7e7fee2bd5f';

/// Dashboard status of one stage for [uid] — always from the server, never
/// a placeholder constant.

@ProviderFor(researchStageStatus)
final researchStageStatusProvider = ResearchStageStatusFamily._();

/// Dashboard status of one stage for [uid] — always from the server, never
/// a placeholder constant.

final class ResearchStageStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<ResearchStageKind>,
          ResearchStageKind,
          FutureOr<ResearchStageKind>
        >
    with
        $FutureModifier<ResearchStageKind>,
        $FutureProvider<ResearchStageKind> {
  /// Dashboard status of one stage for [uid] — always from the server, never
  /// a placeholder constant.
  ResearchStageStatusProvider._({
    required ResearchStageStatusFamily super.from,
    required (String, ResearchStage) super.argument,
  }) : super(
         retry: null,
         name: r'researchStageStatusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$researchStageStatusHash();

  @override
  String toString() {
    return r'researchStageStatusProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<ResearchStageKind> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ResearchStageKind> create(Ref ref) {
    final argument = this.argument as (String, ResearchStage);
    return researchStageStatus(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ResearchStageStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$researchStageStatusHash() =>
    r'91395d8ff9cf4e5ef7a09d0bf1f8df4bc2cbef09';

/// Dashboard status of one stage for [uid] — always from the server, never
/// a placeholder constant.

final class ResearchStageStatusFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ResearchStageKind>,
          (String, ResearchStage)
        > {
  ResearchStageStatusFamily._()
    : super(
        retry: null,
        name: r'researchStageStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Dashboard status of one stage for [uid] — always from the server, never
  /// a placeholder constant.

  ResearchStageStatusProvider call(String uid, ResearchStage stage) =>
      ResearchStageStatusProvider._(argument: (uid, stage), from: this);

  @override
  String toString() => r'researchStageStatusProvider';
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

@ProviderFor(ResearchAssessmentController)
final researchAssessmentControllerProvider =
    ResearchAssessmentControllerFamily._();

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
final class ResearchAssessmentControllerProvider
    extends
        $NotifierProvider<
          ResearchAssessmentController,
          ResearchAssessmentState
        > {
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
  ResearchAssessmentControllerProvider._({
    required ResearchAssessmentControllerFamily super.from,
    required (String, ResearchStage) super.argument,
  }) : super(
         retry: null,
         name: r'researchAssessmentControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$researchAssessmentControllerHash();

  @override
  String toString() {
    return r'researchAssessmentControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ResearchAssessmentController create() => ResearchAssessmentController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResearchAssessmentState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResearchAssessmentState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ResearchAssessmentControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$researchAssessmentControllerHash() =>
    r'b1b7c6484ce886f5d434a2ef0f6fb40c3cfd051b';

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

final class ResearchAssessmentControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ResearchAssessmentController,
          ResearchAssessmentState,
          ResearchAssessmentState,
          ResearchAssessmentState,
          (String, ResearchStage)
        > {
  ResearchAssessmentControllerFamily._()
    : super(
        retry: null,
        name: r'researchAssessmentControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

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

  ResearchAssessmentControllerProvider call(String uid, ResearchStage stage) =>
      ResearchAssessmentControllerProvider._(
        argument: (uid, stage),
        from: this,
      );

  @override
  String toString() => r'researchAssessmentControllerProvider';
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

abstract class _$ResearchAssessmentController
    extends $Notifier<ResearchAssessmentState> {
  late final _$args = ref.$arg as (String, ResearchStage);
  String get uid => _$args.$1;
  ResearchStage get stage => _$args.$2;

  ResearchAssessmentState build(String uid, ResearchStage stage);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<ResearchAssessmentState, ResearchAssessmentState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ResearchAssessmentState, ResearchAssessmentState>,
              ResearchAssessmentState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
