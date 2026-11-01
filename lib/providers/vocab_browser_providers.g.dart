// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vocab_browser_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(VocabBrowserFilter)
final vocabBrowserFilterProvider = VocabBrowserFilterFamily._();

final class VocabBrowserFilterProvider
    extends $NotifierProvider<VocabBrowserFilter, VocabBrowserFilterState> {
  VocabBrowserFilterProvider._({
    required VocabBrowserFilterFamily super.from,
    required VocabBrowserVisit super.argument,
  }) : super(
         retry: null,
         name: r'vocabBrowserFilterProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$vocabBrowserFilterHash();

  @override
  String toString() {
    return r'vocabBrowserFilterProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  VocabBrowserFilter create() => VocabBrowserFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VocabBrowserFilterState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VocabBrowserFilterState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VocabBrowserFilterProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$vocabBrowserFilterHash() =>
    r'c0c4807b37fd21efbe3484e120af7c02c9302da5';

final class VocabBrowserFilterFamily extends $Family
    with
        $ClassFamilyOverride<
          VocabBrowserFilter,
          VocabBrowserFilterState,
          VocabBrowserFilterState,
          VocabBrowserFilterState,
          VocabBrowserVisit
        > {
  VocabBrowserFilterFamily._()
    : super(
        retry: null,
        name: r'vocabBrowserFilterProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  VocabBrowserFilterProvider call(VocabBrowserVisit visit) =>
      VocabBrowserFilterProvider._(argument: visit, from: this);

  @override
  String toString() => r'vocabBrowserFilterProvider';
}

abstract class _$VocabBrowserFilter extends $Notifier<VocabBrowserFilterState> {
  late final _$args = ref.$arg as VocabBrowserVisit;
  VocabBrowserVisit get visit => _$args;

  VocabBrowserFilterState build(VocabBrowserVisit visit);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<VocabBrowserFilterState, VocabBrowserFilterState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VocabBrowserFilterState, VocabBrowserFilterState>,
              VocabBrowserFilterState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
