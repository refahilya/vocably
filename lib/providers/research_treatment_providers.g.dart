// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'research_treatment_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(researchTreatmentService)
final researchTreatmentServiceProvider = ResearchTreatmentServiceProvider._();

final class ResearchTreatmentServiceProvider
    extends
        $FunctionalProvider<
          ResearchTreatmentService,
          ResearchTreatmentService,
          ResearchTreatmentService
        >
    with $Provider<ResearchTreatmentService> {
  ResearchTreatmentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'researchTreatmentServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$researchTreatmentServiceHash();

  @$internal
  @override
  $ProviderElement<ResearchTreatmentService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ResearchTreatmentService create(Ref ref) {
    return researchTreatmentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResearchTreatmentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResearchTreatmentService>(value),
    );
  }
}

String _$researchTreatmentServiceHash() =>
    r'04498147561c6bea29292ec0e173a9b6e344b4b7';

/// Official research sessions open for [studentId] right now (the
/// researcher opened them in class and marked the student present). Live:
/// the same active-target query as a listener, so a session opened while
/// the dashboard is already showing appears by itself. The rules decide
/// whether a session can actually be started.

@ProviderFor(researchSessionOffers)
final researchSessionOffersProvider = ResearchSessionOffersFamily._();

/// Official research sessions open for [studentId] right now (the
/// researcher opened them in class and marked the student present). Live:
/// the same active-target query as a listener, so a session opened while
/// the dashboard is already showing appears by itself. The rules decide
/// whether a session can actually be started.

final class ResearchSessionOffersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ResearchSessionOffer>>,
          List<ResearchSessionOffer>,
          Stream<List<ResearchSessionOffer>>
        >
    with
        $FutureModifier<List<ResearchSessionOffer>>,
        $StreamProvider<List<ResearchSessionOffer>> {
  /// Official research sessions open for [studentId] right now (the
  /// researcher opened them in class and marked the student present). Live:
  /// the same active-target query as a listener, so a session opened while
  /// the dashboard is already showing appears by itself. The rules decide
  /// whether a session can actually be started.
  ResearchSessionOffersProvider._({
    required ResearchSessionOffersFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'researchSessionOffersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$researchSessionOffersHash();

  @override
  String toString() {
    return r'researchSessionOffersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ResearchSessionOffer>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ResearchSessionOffer>> create(Ref ref) {
    final argument = this.argument as String;
    return researchSessionOffers(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ResearchSessionOffersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$researchSessionOffersHash() =>
    r'7dcd55520955e3f37532684d54efe0455861b456';

/// Official research sessions open for [studentId] right now (the
/// researcher opened them in class and marked the student present). Live:
/// the same active-target query as a listener, so a session opened while
/// the dashboard is already showing appears by itself. The rules decide
/// whether a session can actually be started.

final class ResearchSessionOffersFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ResearchSessionOffer>>, String> {
  ResearchSessionOffersFamily._()
    : super(
        retry: null,
        name: r'researchSessionOffersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Official research sessions open for [studentId] right now (the
  /// researcher opened them in class and marked the student present). Live:
  /// the same active-target query as a listener, so a session opened while
  /// the dashboard is already showing appears by itself. The rules decide
  /// whether a session can actually be started.

  ResearchSessionOffersProvider call(String studentId) =>
      ResearchSessionOffersProvider._(argument: studentId, from: this);

  @override
  String toString() => r'researchSessionOffersProvider';
}

/// The five words of an official session, resolved for display.

@ProviderFor(researchSessionEntries)
final researchSessionEntriesProvider = ResearchSessionEntriesFamily._();

/// The five words of an official session, resolved for display.

final class ResearchSessionEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VocabBundleEntry>>,
          List<VocabBundleEntry>,
          FutureOr<List<VocabBundleEntry>>
        >
    with
        $FutureModifier<List<VocabBundleEntry>>,
        $FutureProvider<List<VocabBundleEntry>> {
  /// The five words of an official session, resolved for display.
  ResearchSessionEntriesProvider._({
    required ResearchSessionEntriesFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'researchSessionEntriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$researchSessionEntriesHash();

  @override
  String toString() {
    return r'researchSessionEntriesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<VocabBundleEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VocabBundleEntry>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return researchSessionEntries(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ResearchSessionEntriesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$researchSessionEntriesHash() =>
    r'6e1d2ffc82ad3dc0be358796cefa08f166e48d5a';

/// The five words of an official session, resolved for display.

final class ResearchSessionEntriesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<VocabBundleEntry>>,
          (String, String)
        > {
  ResearchSessionEntriesFamily._()
    : super(
        retry: null,
        name: r'researchSessionEntriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The five words of an official session, resolved for display.

  ResearchSessionEntriesProvider call(String studentId, String setId) =>
      ResearchSessionEntriesProvider._(
        argument: (studentId, setId),
        from: this,
      );

  @override
  String toString() => r'researchSessionEntriesProvider';
}

/// Records any completed official session the app could not record when it
/// ended (best effort; runs when the dashboard opens). Never throws.

@ProviderFor(researchTreatmentReconcile)
final researchTreatmentReconcileProvider = ResearchTreatmentReconcileFamily._();

/// Records any completed official session the app could not record when it
/// ended (best effort; runs when the dashboard opens). Never throws.

final class ResearchTreatmentReconcileProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Records any completed official session the app could not record when it
  /// ended (best effort; runs when the dashboard opens). Never throws.
  ResearchTreatmentReconcileProvider._({
    required ResearchTreatmentReconcileFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'researchTreatmentReconcileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$researchTreatmentReconcileHash();

  @override
  String toString() {
    return r'researchTreatmentReconcileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as String;
    return researchTreatmentReconcile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ResearchTreatmentReconcileProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$researchTreatmentReconcileHash() =>
    r'8514082033b54caed83bfb421d74c3eac64eff75';

/// Records any completed official session the app could not record when it
/// ended (best effort; runs when the dashboard opens). Never throws.

final class ResearchTreatmentReconcileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, String> {
  ResearchTreatmentReconcileFamily._()
    : super(
        retry: null,
        name: r'researchTreatmentReconcileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Records any completed official session the app could not record when it
  /// ended (best effort; runs when the dashboard opens). Never throws.

  ResearchTreatmentReconcileProvider call(String studentId) =>
      ResearchTreatmentReconcileProvider._(argument: studentId, from: this);

  @override
  String toString() => r'researchTreatmentReconcileProvider';
}
