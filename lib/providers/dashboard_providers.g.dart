// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(targetWordSetService)
final targetWordSetServiceProvider = TargetWordSetServiceProvider._();

final class TargetWordSetServiceProvider
    extends
        $FunctionalProvider<
          TargetWordSetService,
          TargetWordSetService,
          TargetWordSetService
        >
    with $Provider<TargetWordSetService> {
  TargetWordSetServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'targetWordSetServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$targetWordSetServiceHash();

  @$internal
  @override
  $ProviderElement<TargetWordSetService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TargetWordSetService create(Ref ref) {
    return targetWordSetService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TargetWordSetService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TargetWordSetService>(value),
    );
  }
}

String _$targetWordSetServiceHash() =>
    r'1526cace1b69a47efd886c1498f4e38b3a2e0469';

/// The `targetWordSets` currently active for [studentId] (`DATA_MODEL.md`
/// §5's query, run as-is — see `TargetWordSetService`). Empty until
/// Milestone 8 builds "Set Target Kata" and a guru actually creates one.

@ProviderFor(activeTargetWordSets)
final activeTargetWordSetsProvider = ActiveTargetWordSetsFamily._();

/// The `targetWordSets` currently active for [studentId] (`DATA_MODEL.md`
/// §5's query, run as-is — see `TargetWordSetService`). Empty until
/// Milestone 8 builds "Set Target Kata" and a guru actually creates one.

final class ActiveTargetWordSetsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TargetWordSet>>,
          List<TargetWordSet>,
          FutureOr<List<TargetWordSet>>
        >
    with
        $FutureModifier<List<TargetWordSet>>,
        $FutureProvider<List<TargetWordSet>> {
  /// The `targetWordSets` currently active for [studentId] (`DATA_MODEL.md`
  /// §5's query, run as-is — see `TargetWordSetService`). Empty until
  /// Milestone 8 builds "Set Target Kata" and a guru actually creates one.
  ActiveTargetWordSetsProvider._({
    required ActiveTargetWordSetsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'activeTargetWordSetsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activeTargetWordSetsHash();

  @override
  String toString() {
    return r'activeTargetWordSetsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TargetWordSet>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TargetWordSet>> create(Ref ref) {
    final argument = this.argument as String;
    return activeTargetWordSets(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ActiveTargetWordSetsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activeTargetWordSetsHash() =>
    r'1d93190fac4448ab6fbcfe48cf241bc43f0ad2ea';

/// The `targetWordSets` currently active for [studentId] (`DATA_MODEL.md`
/// §5's query, run as-is — see `TargetWordSetService`). Empty until
/// Milestone 8 builds "Set Target Kata" and a guru actually creates one.

final class ActiveTargetWordSetsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TargetWordSet>>, String> {
  ActiveTargetWordSetsFamily._()
    : super(
        retry: null,
        name: r'activeTargetWordSetsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The `targetWordSets` currently active for [studentId] (`DATA_MODEL.md`
  /// §5's query, run as-is — see `TargetWordSetService`). Empty until
  /// Milestone 8 builds "Set Target Kata" and a guru actually creates one.

  ActiveTargetWordSetsProvider call(String studentId) =>
      ActiveTargetWordSetsProvider._(argument: studentId, from: this);

  @override
  String toString() => r'activeTargetWordSetsProvider';
}

/// Resolves every currently-active target word (across however many
/// active sets exist) to its full [VocabBundleEntry], for the "Target
/// Kata Hari Ini" card.
///
/// Each [TargetWordSet] is scoped to one `cefrLevel` (`DATA_MODEL.md`
/// §5's own framing — a guru picks words starting from one level), so
/// resolution loads that one level's bundle per set (reusing
/// [vocabLevelProvider]'s cache — repeated levels across multiple active
/// sets don't reload) and matches each `wordId` against it by exact
/// (already-normalized) string equality. A `wordId` that no longer
/// resolves (e.g. a word later removed from the bank — not possible
/// today since `vocabWords` has no delete path, but not assumed away
/// either) is silently skipped rather than shown as a broken entry.
/// Results are de-duplicated by word, since more than one active set
/// could target the same word.

@ProviderFor(targetWordEntries)
final targetWordEntriesProvider = TargetWordEntriesFamily._();

/// Resolves every currently-active target word (across however many
/// active sets exist) to its full [VocabBundleEntry], for the "Target
/// Kata Hari Ini" card.
///
/// Each [TargetWordSet] is scoped to one `cefrLevel` (`DATA_MODEL.md`
/// §5's own framing — a guru picks words starting from one level), so
/// resolution loads that one level's bundle per set (reusing
/// [vocabLevelProvider]'s cache — repeated levels across multiple active
/// sets don't reload) and matches each `wordId` against it by exact
/// (already-normalized) string equality. A `wordId` that no longer
/// resolves (e.g. a word later removed from the bank — not possible
/// today since `vocabWords` has no delete path, but not assumed away
/// either) is silently skipped rather than shown as a broken entry.
/// Results are de-duplicated by word, since more than one active set
/// could target the same word.

final class TargetWordEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VocabBundleEntry>>,
          List<VocabBundleEntry>,
          FutureOr<List<VocabBundleEntry>>
        >
    with
        $FutureModifier<List<VocabBundleEntry>>,
        $FutureProvider<List<VocabBundleEntry>> {
  /// Resolves every currently-active target word (across however many
  /// active sets exist) to its full [VocabBundleEntry], for the "Target
  /// Kata Hari Ini" card.
  ///
  /// Each [TargetWordSet] is scoped to one `cefrLevel` (`DATA_MODEL.md`
  /// §5's own framing — a guru picks words starting from one level), so
  /// resolution loads that one level's bundle per set (reusing
  /// [vocabLevelProvider]'s cache — repeated levels across multiple active
  /// sets don't reload) and matches each `wordId` against it by exact
  /// (already-normalized) string equality. A `wordId` that no longer
  /// resolves (e.g. a word later removed from the bank — not possible
  /// today since `vocabWords` has no delete path, but not assumed away
  /// either) is silently skipped rather than shown as a broken entry.
  /// Results are de-duplicated by word, since more than one active set
  /// could target the same word.
  TargetWordEntriesProvider._({
    required TargetWordEntriesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'targetWordEntriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$targetWordEntriesHash();

  @override
  String toString() {
    return r'targetWordEntriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<VocabBundleEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VocabBundleEntry>> create(Ref ref) {
    final argument = this.argument as String;
    return targetWordEntries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TargetWordEntriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$targetWordEntriesHash() => r'20ef628ca4a3be475781c8400635399d21730a08';

/// Resolves every currently-active target word (across however many
/// active sets exist) to its full [VocabBundleEntry], for the "Target
/// Kata Hari Ini" card.
///
/// Each [TargetWordSet] is scoped to one `cefrLevel` (`DATA_MODEL.md`
/// §5's own framing — a guru picks words starting from one level), so
/// resolution loads that one level's bundle per set (reusing
/// [vocabLevelProvider]'s cache — repeated levels across multiple active
/// sets don't reload) and matches each `wordId` against it by exact
/// (already-normalized) string equality. A `wordId` that no longer
/// resolves (e.g. a word later removed from the bank — not possible
/// today since `vocabWords` has no delete path, but not assumed away
/// either) is silently skipped rather than shown as a broken entry.
/// Results are de-duplicated by word, since more than one active set
/// could target the same word.

final class TargetWordEntriesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<VocabBundleEntry>>, String> {
  TargetWordEntriesFamily._()
    : super(
        retry: null,
        name: r'targetWordEntriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Resolves every currently-active target word (across however many
  /// active sets exist) to its full [VocabBundleEntry], for the "Target
  /// Kata Hari Ini" card.
  ///
  /// Each [TargetWordSet] is scoped to one `cefrLevel` (`DATA_MODEL.md`
  /// §5's own framing — a guru picks words starting from one level), so
  /// resolution loads that one level's bundle per set (reusing
  /// [vocabLevelProvider]'s cache — repeated levels across multiple active
  /// sets don't reload) and matches each `wordId` against it by exact
  /// (already-normalized) string equality. A `wordId` that no longer
  /// resolves (e.g. a word later removed from the bank — not possible
  /// today since `vocabWords` has no delete path, but not assumed away
  /// either) is silently skipped rather than shown as a broken entry.
  /// Results are de-duplicated by word, since more than one active set
  /// could target the same word.

  TargetWordEntriesProvider call(String studentId) =>
      TargetWordEntriesProvider._(argument: studentId, from: this);

  @override
  String toString() => r'targetWordEntriesProvider';
}
