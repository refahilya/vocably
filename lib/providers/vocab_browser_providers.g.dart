// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vocab_browser_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(VocabBrowserFilter)
final vocabBrowserFilterProvider = VocabBrowserFilterProvider._();

final class VocabBrowserFilterProvider
    extends $NotifierProvider<VocabBrowserFilter, VocabBrowserFilterState> {
  VocabBrowserFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vocabBrowserFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vocabBrowserFilterHash();

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
}

String _$vocabBrowserFilterHash() =>
    r'cb4b3514aaeed727a726c64275b0ea36d3d39ac6';

abstract class _$VocabBrowserFilter extends $Notifier<VocabBrowserFilterState> {
  VocabBrowserFilterState build();
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
    return element.handleCreate(ref, build);
  }
}
