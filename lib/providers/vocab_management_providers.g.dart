// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vocab_management_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(vocabWordService)
final vocabWordServiceProvider = VocabWordServiceProvider._();

final class VocabWordServiceProvider
    extends
        $FunctionalProvider<
          VocabWordService,
          VocabWordService,
          VocabWordService
        >
    with $Provider<VocabWordService> {
  VocabWordServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vocabWordServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vocabWordServiceHash();

  @$internal
  @override
  $ProviderElement<VocabWordService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VocabWordService create(Ref ref) {
    return vocabWordService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VocabWordService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VocabWordService>(value),
    );
  }
}

String _$vocabWordServiceHash() => r'2b0c3016b5eaaa88faca617e4d5d5f8d69070b68';

@ProviderFor(topicsService)
final topicsServiceProvider = TopicsServiceProvider._();

final class TopicsServiceProvider
    extends $FunctionalProvider<TopicsService, TopicsService, TopicsService>
    with $Provider<TopicsService> {
  TopicsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'topicsServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$topicsServiceHash();

  @$internal
  @override
  $ProviderElement<TopicsService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TopicsService create(Ref ref) {
    return topicsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TopicsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TopicsService>(value),
    );
  }
}

String _$topicsServiceHash() => r'd62781a31e928b64e2fbf446147c6dfe058d38fa';

/// The canonical `topics` master list (`DATA_MODEL.md` §2b) — small
/// collection, always read live. Used by Tambah Kosakata's topic
/// multi-select chips.

@ProviderFor(topicsList)
final topicsListProvider = TopicsListProvider._();

/// The canonical `topics` master list (`DATA_MODEL.md` §2b) — small
/// collection, always read live. Used by Tambah Kosakata's topic
/// multi-select chips.

final class TopicsListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Topic>>,
          List<Topic>,
          FutureOr<List<Topic>>
        >
    with $FutureModifier<List<Topic>>, $FutureProvider<List<Topic>> {
  /// The canonical `topics` master list (`DATA_MODEL.md` §2b) — small
  /// collection, always read live. Used by Tambah Kosakata's topic
  /// multi-select chips.
  TopicsListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'topicsListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$topicsListHash();

  @$internal
  @override
  $FutureProviderElement<List<Topic>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Topic>> create(Ref ref) {
    return topicsList(ref);
  }
}

String _$topicsListHash() => r'9ab5d0ac5e813130c8af929bfb94a7e45be8c16d';

/// Looks up an existing `vocabWords` document by [rawWord] (normalized
/// internally) — the "duplicate check on blur" step of Tambah Kosakata
/// (`SPEC.md` §4.1). `null` means the word doesn't exist yet.

@ProviderFor(vocabWordLookup)
final vocabWordLookupProvider = VocabWordLookupFamily._();

/// Looks up an existing `vocabWords` document by [rawWord] (normalized
/// internally) — the "duplicate check on blur" step of Tambah Kosakata
/// (`SPEC.md` §4.1). `null` means the word doesn't exist yet.

final class VocabWordLookupProvider
    extends
        $FunctionalProvider<
          AsyncValue<VocabWord?>,
          VocabWord?,
          FutureOr<VocabWord?>
        >
    with $FutureModifier<VocabWord?>, $FutureProvider<VocabWord?> {
  /// Looks up an existing `vocabWords` document by [rawWord] (normalized
  /// internally) — the "duplicate check on blur" step of Tambah Kosakata
  /// (`SPEC.md` §4.1). `null` means the word doesn't exist yet.
  VocabWordLookupProvider._({
    required VocabWordLookupFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'vocabWordLookupProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$vocabWordLookupHash();

  @override
  String toString() {
    return r'vocabWordLookupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<VocabWord?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<VocabWord?> create(Ref ref) {
    final argument = this.argument as String;
    return vocabWordLookup(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VocabWordLookupProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$vocabWordLookupHash() => r'42e2f243d8662dc5ec7c0267c010f3baf9b9091a';

/// Looks up an existing `vocabWords` document by [rawWord] (normalized
/// internally) — the "duplicate check on blur" step of Tambah Kosakata
/// (`SPEC.md` §4.1). `null` means the word doesn't exist yet.

final class VocabWordLookupFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<VocabWord?>, String> {
  VocabWordLookupFamily._()
    : super(
        retry: null,
        name: r'vocabWordLookupProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Looks up an existing `vocabWords` document by [rawWord] (normalized
  /// internally) — the "duplicate check on blur" step of Tambah Kosakata
  /// (`SPEC.md` §4.1). `null` means the word doesn't exist yet.

  VocabWordLookupProvider call(String rawWord) =>
      VocabWordLookupProvider._(argument: rawWord, from: this);

  @override
  String toString() => r'vocabWordLookupProvider';
}

/// Drives the two guru "Tambah Kosakata" write flows (`SPEC.md` §4.1):
/// creating a brand-new word, or appending a new meaning to an existing
/// one. [state] reflects only these two "real" submissions — the
/// lighter-weight supporting actions ([generateTranslation],
/// [addNewTopic]) deliberately don't touch it, so a per-row translation
/// preview or adding one topic doesn't flip the whole form into a
/// submitting/disabled state.

@ProviderFor(TambahKosakataController)
final tambahKosakataControllerProvider = TambahKosakataControllerProvider._();

/// Drives the two guru "Tambah Kosakata" write flows (`SPEC.md` §4.1):
/// creating a brand-new word, or appending a new meaning to an existing
/// one. [state] reflects only these two "real" submissions — the
/// lighter-weight supporting actions ([generateTranslation],
/// [addNewTopic]) deliberately don't touch it, so a per-row translation
/// preview or adding one topic doesn't flip the whole form into a
/// submitting/disabled state.
final class TambahKosakataControllerProvider
    extends $AsyncNotifierProvider<TambahKosakataController, void> {
  /// Drives the two guru "Tambah Kosakata" write flows (`SPEC.md` §4.1):
  /// creating a brand-new word, or appending a new meaning to an existing
  /// one. [state] reflects only these two "real" submissions — the
  /// lighter-weight supporting actions ([generateTranslation],
  /// [addNewTopic]) deliberately don't touch it, so a per-row translation
  /// preview or adding one topic doesn't flip the whole form into a
  /// submitting/disabled state.
  TambahKosakataControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tambahKosakataControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tambahKosakataControllerHash();

  @$internal
  @override
  TambahKosakataController create() => TambahKosakataController();
}

String _$tambahKosakataControllerHash() =>
    r'9b8ed8cc7efb1f9eea518e653df8f2793a15c7ba';

/// Drives the two guru "Tambah Kosakata" write flows (`SPEC.md` §4.1):
/// creating a brand-new word, or appending a new meaning to an existing
/// one. [state] reflects only these two "real" submissions — the
/// lighter-weight supporting actions ([generateTranslation],
/// [addNewTopic]) deliberately don't touch it, so a per-row translation
/// preview or adding one topic doesn't flip the whole form into a
/// submitting/disabled state.

abstract class _$TambahKosakataController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Drives the guru "Edit Kata" write flow (`SPEC.md` §4.1, Milestone 8).
/// Updates only `topics` (and `updatedAt`) for an existing vocabulary word.

@ProviderFor(EditKataController)
final editKataControllerProvider = EditKataControllerProvider._();

/// Drives the guru "Edit Kata" write flow (`SPEC.md` §4.1, Milestone 8).
/// Updates only `topics` (and `updatedAt`) for an existing vocabulary word.
final class EditKataControllerProvider
    extends $AsyncNotifierProvider<EditKataController, void> {
  /// Drives the guru "Edit Kata" write flow (`SPEC.md` §4.1, Milestone 8).
  /// Updates only `topics` (and `updatedAt`) for an existing vocabulary word.
  EditKataControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editKataControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editKataControllerHash();

  @$internal
  @override
  EditKataController create() => EditKataController();
}

String _$editKataControllerHash() =>
    r'11322477e19709cf090cbcf03f18ffb66a24af98';

/// Drives the guru "Edit Kata" write flow (`SPEC.md` §4.1, Milestone 8).
/// Updates only `topics` (and `updatedAt`) for an existing vocabulary word.

abstract class _$EditKataController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
