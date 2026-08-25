// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vocab_bundle_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(vocabBundleService)
final vocabBundleServiceProvider = VocabBundleServiceProvider._();

final class VocabBundleServiceProvider
    extends
        $FunctionalProvider<
          VocabBundleService,
          VocabBundleService,
          VocabBundleService
        >
    with $Provider<VocabBundleService> {
  VocabBundleServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vocabBundleServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vocabBundleServiceHash();

  @$internal
  @override
  $ProviderElement<VocabBundleService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VocabBundleService create(Ref ref) {
    return vocabBundleService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VocabBundleService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VocabBundleService>(value),
    );
  }
}

String _$vocabBundleServiceHash() =>
    r'6a03d97ebdc6af1e95239c5cd36e33954f5a5734';

/// Bundle for one CEFR level, merged with anything newer from Firestore
/// (`DATA_MODEL.md` §11.3). A family provider — one cached result per
/// `cefrLevel` string, matching how browse is always scoped to a single
/// level at a time (`SPEC.md` §3.2/§3.3).
///
/// `AsyncValue`'s own loading/error/data states satisfy "handle loading/
/// error/empty states cleanly" without extra plumbing here: a level with
/// no words yet (e.g. C2 today) resolves to `AsyncData(const [])` — an
/// empty list is valid data, not an error — while a genuine failure
/// (Firestore unreachable, etc.) surfaces as `AsyncError` for a later
/// stage's UI to render per `DESIGN_REFERENCE.md` §5.8's empty/error
/// states table.

@ProviderFor(vocabLevel)
final vocabLevelProvider = VocabLevelFamily._();

/// Bundle for one CEFR level, merged with anything newer from Firestore
/// (`DATA_MODEL.md` §11.3). A family provider — one cached result per
/// `cefrLevel` string, matching how browse is always scoped to a single
/// level at a time (`SPEC.md` §3.2/§3.3).
///
/// `AsyncValue`'s own loading/error/data states satisfy "handle loading/
/// error/empty states cleanly" without extra plumbing here: a level with
/// no words yet (e.g. C2 today) resolves to `AsyncData(const [])` — an
/// empty list is valid data, not an error — while a genuine failure
/// (Firestore unreachable, etc.) surfaces as `AsyncError` for a later
/// stage's UI to render per `DESIGN_REFERENCE.md` §5.8's empty/error
/// states table.

final class VocabLevelProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VocabBundleEntry>>,
          List<VocabBundleEntry>,
          FutureOr<List<VocabBundleEntry>>
        >
    with
        $FutureModifier<List<VocabBundleEntry>>,
        $FutureProvider<List<VocabBundleEntry>> {
  /// Bundle for one CEFR level, merged with anything newer from Firestore
  /// (`DATA_MODEL.md` §11.3). A family provider — one cached result per
  /// `cefrLevel` string, matching how browse is always scoped to a single
  /// level at a time (`SPEC.md` §3.2/§3.3).
  ///
  /// `AsyncValue`'s own loading/error/data states satisfy "handle loading/
  /// error/empty states cleanly" without extra plumbing here: a level with
  /// no words yet (e.g. C2 today) resolves to `AsyncData(const [])` — an
  /// empty list is valid data, not an error — while a genuine failure
  /// (Firestore unreachable, etc.) surfaces as `AsyncError` for a later
  /// stage's UI to render per `DESIGN_REFERENCE.md` §5.8's empty/error
  /// states table.
  VocabLevelProvider._({
    required VocabLevelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'vocabLevelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$vocabLevelHash();

  @override
  String toString() {
    return r'vocabLevelProvider'
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
    return vocabLevel(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VocabLevelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$vocabLevelHash() => r'217509befdcd41f4bfb1ca9d9e14661475650ca1';

/// Bundle for one CEFR level, merged with anything newer from Firestore
/// (`DATA_MODEL.md` §11.3). A family provider — one cached result per
/// `cefrLevel` string, matching how browse is always scoped to a single
/// level at a time (`SPEC.md` §3.2/§3.3).
///
/// `AsyncValue`'s own loading/error/data states satisfy "handle loading/
/// error/empty states cleanly" without extra plumbing here: a level with
/// no words yet (e.g. C2 today) resolves to `AsyncData(const [])` — an
/// empty list is valid data, not an error — while a genuine failure
/// (Firestore unreachable, etc.) surfaces as `AsyncError` for a later
/// stage's UI to render per `DESIGN_REFERENCE.md` §5.8's empty/error
/// states table.

final class VocabLevelFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<VocabBundleEntry>>, String> {
  VocabLevelFamily._()
    : super(
        retry: null,
        name: r'vocabLevelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Bundle for one CEFR level, merged with anything newer from Firestore
  /// (`DATA_MODEL.md` §11.3). A family provider — one cached result per
  /// `cefrLevel` string, matching how browse is always scoped to a single
  /// level at a time (`SPEC.md` §3.2/§3.3).
  ///
  /// `AsyncValue`'s own loading/error/data states satisfy "handle loading/
  /// error/empty states cleanly" without extra plumbing here: a level with
  /// no words yet (e.g. C2 today) resolves to `AsyncData(const [])` — an
  /// empty list is valid data, not an error — while a genuine failure
  /// (Firestore unreachable, etc.) surfaces as `AsyncError` for a later
  /// stage's UI to render per `DESIGN_REFERENCE.md` §5.8's empty/error
  /// states table.

  VocabLevelProvider call(String cefrLevel) =>
      VocabLevelProvider._(argument: cefrLevel, from: this);

  @override
  String toString() => r'vocabLevelProvider';
}
