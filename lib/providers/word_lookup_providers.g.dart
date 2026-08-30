// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_lookup_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Resolves [wordId] (already `normalizeWord()`-ed) to its full
/// [VocabBundleEntry] by checking each of [kCefrLevels] in turn — the
/// same "no single `cefrLevel` to scope to" problem
/// `history_providers.dart`'s `historyWordEntriesProvider` already solved
/// for Riwayat's "Per Kata" tab, factored out here so Fase 1's
/// tap-a-target-word-to-open-its-dictionary-entry
/// (`SPEC.md` §5.1) can reuse the exact same lookup instead of
/// re-implementing it. Reuses [vocabLevelProvider]'s cache, so a level
/// already loaded elsewhere costs nothing extra here.

@ProviderFor(resolveWordAcrossLevels)
final resolveWordAcrossLevelsProvider = ResolveWordAcrossLevelsFamily._();

/// Resolves [wordId] (already `normalizeWord()`-ed) to its full
/// [VocabBundleEntry] by checking each of [kCefrLevels] in turn — the
/// same "no single `cefrLevel` to scope to" problem
/// `history_providers.dart`'s `historyWordEntriesProvider` already solved
/// for Riwayat's "Per Kata" tab, factored out here so Fase 1's
/// tap-a-target-word-to-open-its-dictionary-entry
/// (`SPEC.md` §5.1) can reuse the exact same lookup instead of
/// re-implementing it. Reuses [vocabLevelProvider]'s cache, so a level
/// already loaded elsewhere costs nothing extra here.

final class ResolveWordAcrossLevelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<VocabBundleEntry?>,
          VocabBundleEntry?,
          FutureOr<VocabBundleEntry?>
        >
    with
        $FutureModifier<VocabBundleEntry?>,
        $FutureProvider<VocabBundleEntry?> {
  /// Resolves [wordId] (already `normalizeWord()`-ed) to its full
  /// [VocabBundleEntry] by checking each of [kCefrLevels] in turn — the
  /// same "no single `cefrLevel` to scope to" problem
  /// `history_providers.dart`'s `historyWordEntriesProvider` already solved
  /// for Riwayat's "Per Kata" tab, factored out here so Fase 1's
  /// tap-a-target-word-to-open-its-dictionary-entry
  /// (`SPEC.md` §5.1) can reuse the exact same lookup instead of
  /// re-implementing it. Reuses [vocabLevelProvider]'s cache, so a level
  /// already loaded elsewhere costs nothing extra here.
  ResolveWordAcrossLevelsProvider._({
    required ResolveWordAcrossLevelsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'resolveWordAcrossLevelsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$resolveWordAcrossLevelsHash();

  @override
  String toString() {
    return r'resolveWordAcrossLevelsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<VocabBundleEntry?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<VocabBundleEntry?> create(Ref ref) {
    final argument = this.argument as String;
    return resolveWordAcrossLevels(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ResolveWordAcrossLevelsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$resolveWordAcrossLevelsHash() =>
    r'd9a129c6b9e88e34c4fe961884af381545f3ea68';

/// Resolves [wordId] (already `normalizeWord()`-ed) to its full
/// [VocabBundleEntry] by checking each of [kCefrLevels] in turn — the
/// same "no single `cefrLevel` to scope to" problem
/// `history_providers.dart`'s `historyWordEntriesProvider` already solved
/// for Riwayat's "Per Kata" tab, factored out here so Fase 1's
/// tap-a-target-word-to-open-its-dictionary-entry
/// (`SPEC.md` §5.1) can reuse the exact same lookup instead of
/// re-implementing it. Reuses [vocabLevelProvider]'s cache, so a level
/// already loaded elsewhere costs nothing extra here.

final class ResolveWordAcrossLevelsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<VocabBundleEntry?>, String> {
  ResolveWordAcrossLevelsFamily._()
    : super(
        retry: null,
        name: r'resolveWordAcrossLevelsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Resolves [wordId] (already `normalizeWord()`-ed) to its full
  /// [VocabBundleEntry] by checking each of [kCefrLevels] in turn — the
  /// same "no single `cefrLevel` to scope to" problem
  /// `history_providers.dart`'s `historyWordEntriesProvider` already solved
  /// for Riwayat's "Per Kata" tab, factored out here so Fase 1's
  /// tap-a-target-word-to-open-its-dictionary-entry
  /// (`SPEC.md` §5.1) can reuse the exact same lookup instead of
  /// re-implementing it. Reuses [vocabLevelProvider]'s cache, so a level
  /// already loaded elsewhere costs nothing extra here.

  ResolveWordAcrossLevelsProvider call(String wordId) =>
      ResolveWordAcrossLevelsProvider._(argument: wordId, from: this);

  @override
  String toString() => r'resolveWordAcrossLevelsProvider';
}
