// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(learningProgressService)
final learningProgressServiceProvider = LearningProgressServiceProvider._();

final class LearningProgressServiceProvider
    extends
        $FunctionalProvider<
          LearningProgressService,
          LearningProgressService,
          LearningProgressService
        >
    with $Provider<LearningProgressService> {
  LearningProgressServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'learningProgressServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$learningProgressServiceHash();

  @$internal
  @override
  $ProviderElement<LearningProgressService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LearningProgressService create(Ref ref) {
    return learningProgressService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LearningProgressService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LearningProgressService>(value),
    );
  }
}

String _$learningProgressServiceHash() =>
    r'3c3be1ac9eb69761a8e453178b33b5a164a5815d';

@ProviderFor(learningSessionService)
final learningSessionServiceProvider = LearningSessionServiceProvider._();

final class LearningSessionServiceProvider
    extends
        $FunctionalProvider<
          LearningSessionService,
          LearningSessionService,
          LearningSessionService
        >
    with $Provider<LearningSessionService> {
  LearningSessionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'learningSessionServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$learningSessionServiceHash();

  @$internal
  @override
  $ProviderElement<LearningSessionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LearningSessionService create(Ref ref) {
    return learningSessionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LearningSessionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LearningSessionService>(value),
    );
  }
}

String _$learningSessionServiceHash() =>
    r'352e21ed64f50ef7addf54fb86db2da40840320e';

/// Every `learningProgress` row for [studentId], unsorted (see
/// [LearningProgressService]'s doc comment on why sorting/filtering is
/// left to callers). Empty until Milestone 7 starts writing this
/// collection.

@ProviderFor(learningProgressList)
final learningProgressListProvider = LearningProgressListFamily._();

/// Every `learningProgress` row for [studentId], unsorted (see
/// [LearningProgressService]'s doc comment on why sorting/filtering is
/// left to callers). Empty until Milestone 7 starts writing this
/// collection.

final class LearningProgressListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LearningProgress>>,
          List<LearningProgress>,
          FutureOr<List<LearningProgress>>
        >
    with
        $FutureModifier<List<LearningProgress>>,
        $FutureProvider<List<LearningProgress>> {
  /// Every `learningProgress` row for [studentId], unsorted (see
  /// [LearningProgressService]'s doc comment on why sorting/filtering is
  /// left to callers). Empty until Milestone 7 starts writing this
  /// collection.
  LearningProgressListProvider._({
    required LearningProgressListFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'learningProgressListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$learningProgressListHash();

  @override
  String toString() {
    return r'learningProgressListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<LearningProgress>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LearningProgress>> create(Ref ref) {
    final argument = this.argument as String;
    return learningProgressList(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LearningProgressListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$learningProgressListHash() =>
    r'4c18f5455e809882cd71ed9e4d693c7fed6504c9';

/// Every `learningProgress` row for [studentId], unsorted (see
/// [LearningProgressService]'s doc comment on why sorting/filtering is
/// left to callers). Empty until Milestone 7 starts writing this
/// collection.

final class LearningProgressListFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<LearningProgress>>, String> {
  LearningProgressListFamily._()
    : super(
        retry: null,
        name: r'learningProgressListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Every `learningProgress` row for [studentId], unsorted (see
  /// [LearningProgressService]'s doc comment on why sorting/filtering is
  /// left to callers). Empty until Milestone 7 starts writing this
  /// collection.

  LearningProgressListProvider call(String studentId) =>
      LearningProgressListProvider._(argument: studentId, from: this);

  @override
  String toString() => r'learningProgressListProvider';
}

/// Every `learningSessions` row for [studentId], sorted by `startedAt`
/// **descending** — most recent session first, matching Riwayat "Per
/// Sesi"'s expected order. Empty until Milestone 7 starts writing this
/// collection.

@ProviderFor(learningSessionList)
final learningSessionListProvider = LearningSessionListFamily._();

/// Every `learningSessions` row for [studentId], sorted by `startedAt`
/// **descending** — most recent session first, matching Riwayat "Per
/// Sesi"'s expected order. Empty until Milestone 7 starts writing this
/// collection.

final class LearningSessionListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LearningSession>>,
          List<LearningSession>,
          FutureOr<List<LearningSession>>
        >
    with
        $FutureModifier<List<LearningSession>>,
        $FutureProvider<List<LearningSession>> {
  /// Every `learningSessions` row for [studentId], sorted by `startedAt`
  /// **descending** — most recent session first, matching Riwayat "Per
  /// Sesi"'s expected order. Empty until Milestone 7 starts writing this
  /// collection.
  LearningSessionListProvider._({
    required LearningSessionListFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'learningSessionListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$learningSessionListHash();

  @override
  String toString() {
    return r'learningSessionListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<LearningSession>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LearningSession>> create(Ref ref) {
    final argument = this.argument as String;
    return learningSessionList(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LearningSessionListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$learningSessionListHash() =>
    r'a5ea8793ed37040d7615ccab645ec1247e6cadef';

/// Every `learningSessions` row for [studentId], sorted by `startedAt`
/// **descending** — most recent session first, matching Riwayat "Per
/// Sesi"'s expected order. Empty until Milestone 7 starts writing this
/// collection.

final class LearningSessionListFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<LearningSession>>, String> {
  LearningSessionListFamily._()
    : super(
        retry: null,
        name: r'learningSessionListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Every `learningSessions` row for [studentId], sorted by `startedAt`
  /// **descending** — most recent session first, matching Riwayat "Per
  /// Sesi"'s expected order. Empty until Milestone 7 starts writing this
  /// collection.

  LearningSessionListProvider call(String studentId) =>
      LearningSessionListProvider._(argument: studentId, from: this);

  @override
  String toString() => r'learningSessionListProvider';
}

/// Resolves every "Per Kata" row for [studentId].
///
/// Unlike [targetWordEntriesProvider] (Dashboard), a [LearningProgress]
/// row carries no `cefrLevel` of its own — a student's learned words can
/// span any level. Resolution therefore checks each of [kCefrLevels] in
/// turn until a match is found, reusing [vocabLevelProvider]'s cache (a
/// level already loaded for browsing costs nothing extra here). This is
/// at most 6 cached lookups per word, and — since nothing writes
/// `learningProgress` before Milestone 7 — resolves against an empty list
/// in every real run of this milestone.

@ProviderFor(historyWordEntries)
final historyWordEntriesProvider = HistoryWordEntriesFamily._();

/// Resolves every "Per Kata" row for [studentId].
///
/// Unlike [targetWordEntriesProvider] (Dashboard), a [LearningProgress]
/// row carries no `cefrLevel` of its own — a student's learned words can
/// span any level. Resolution therefore checks each of [kCefrLevels] in
/// turn until a match is found, reusing [vocabLevelProvider]'s cache (a
/// level already loaded for browsing costs nothing extra here). This is
/// at most 6 cached lookups per word, and — since nothing writes
/// `learningProgress` before Milestone 7 — resolves against an empty list
/// in every real run of this milestone.

final class HistoryWordEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HistoryWordEntry>>,
          List<HistoryWordEntry>,
          FutureOr<List<HistoryWordEntry>>
        >
    with
        $FutureModifier<List<HistoryWordEntry>>,
        $FutureProvider<List<HistoryWordEntry>> {
  /// Resolves every "Per Kata" row for [studentId].
  ///
  /// Unlike [targetWordEntriesProvider] (Dashboard), a [LearningProgress]
  /// row carries no `cefrLevel` of its own — a student's learned words can
  /// span any level. Resolution therefore checks each of [kCefrLevels] in
  /// turn until a match is found, reusing [vocabLevelProvider]'s cache (a
  /// level already loaded for browsing costs nothing extra here). This is
  /// at most 6 cached lookups per word, and — since nothing writes
  /// `learningProgress` before Milestone 7 — resolves against an empty list
  /// in every real run of this milestone.
  HistoryWordEntriesProvider._({
    required HistoryWordEntriesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'historyWordEntriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$historyWordEntriesHash();

  @override
  String toString() {
    return r'historyWordEntriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<HistoryWordEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<HistoryWordEntry>> create(Ref ref) {
    final argument = this.argument as String;
    return historyWordEntries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HistoryWordEntriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$historyWordEntriesHash() =>
    r'eb90ce793e4d007a1469abc371d981df22584c6c';

/// Resolves every "Per Kata" row for [studentId].
///
/// Unlike [targetWordEntriesProvider] (Dashboard), a [LearningProgress]
/// row carries no `cefrLevel` of its own — a student's learned words can
/// span any level. Resolution therefore checks each of [kCefrLevels] in
/// turn until a match is found, reusing [vocabLevelProvider]'s cache (a
/// level already loaded for browsing costs nothing extra here). This is
/// at most 6 cached lookups per word, and — since nothing writes
/// `learningProgress` before Milestone 7 — resolves against an empty list
/// in every real run of this milestone.

final class HistoryWordEntriesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<HistoryWordEntry>>, String> {
  HistoryWordEntriesFamily._()
    : super(
        retry: null,
        name: r'historyWordEntriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Resolves every "Per Kata" row for [studentId].
  ///
  /// Unlike [targetWordEntriesProvider] (Dashboard), a [LearningProgress]
  /// row carries no `cefrLevel` of its own — a student's learned words can
  /// span any level. Resolution therefore checks each of [kCefrLevels] in
  /// turn until a match is found, reusing [vocabLevelProvider]'s cache (a
  /// level already loaded for browsing costs nothing extra here). This is
  /// at most 6 cached lookups per word, and — since nothing writes
  /// `learningProgress` before Milestone 7 — resolves against an empty list
  /// in every real run of this milestone.

  HistoryWordEntriesProvider call(String studentId) =>
      HistoryWordEntriesProvider._(argument: studentId, from: this);

  @override
  String toString() => r'historyWordEntriesProvider';
}

@ProviderFor(HistoryFilter)
final historyFilterProvider = HistoryFilterProvider._();

final class HistoryFilterProvider
    extends $NotifierProvider<HistoryFilter, HistoryMasteryFilter> {
  HistoryFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyFilterHash();

  @$internal
  @override
  HistoryFilter create() => HistoryFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HistoryMasteryFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HistoryMasteryFilter>(value),
    );
  }
}

String _$historyFilterHash() => r'5743f149558dbbf842e56aaacd56a2c30a21a888';

abstract class _$HistoryFilter extends $Notifier<HistoryMasteryFilter> {
  HistoryMasteryFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<HistoryMasteryFilter, HistoryMasteryFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HistoryMasteryFilter, HistoryMasteryFilter>,
              HistoryMasteryFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
