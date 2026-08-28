// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lazy_translation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Lazy translation display for Word Detail (`DATA_MODEL.md` §2 point 4,
/// `DESIGN_REFERENCE.md` §5.8) — when a meaning's `translation` is
/// `null`, the student client calls `/translate` and shows the result
/// **on-screen only**; it is never written back to Firestore (that
/// distinction lives entirely on the calling side, not in
/// `AiWorkerService` itself — see its doc comment).
///
/// `@riverpod` (not `.family` manually) already caches per `(word, pos)`
/// argument pair for the lifetime of the provider container — i.e. for
/// the rest of the app session — which is exactly the "cache di memori
/// selama sesi aplikasi berjalan" behavior `DATA_MODEL.md` §2 asks for,
/// with no extra caching code needed.

@ProviderFor(lazyTranslation)
final lazyTranslationProvider = LazyTranslationFamily._();

/// Lazy translation display for Word Detail (`DATA_MODEL.md` §2 point 4,
/// `DESIGN_REFERENCE.md` §5.8) — when a meaning's `translation` is
/// `null`, the student client calls `/translate` and shows the result
/// **on-screen only**; it is never written back to Firestore (that
/// distinction lives entirely on the calling side, not in
/// `AiWorkerService` itself — see its doc comment).
///
/// `@riverpod` (not `.family` manually) already caches per `(word, pos)`
/// argument pair for the lifetime of the provider container — i.e. for
/// the rest of the app session — which is exactly the "cache di memori
/// selama sesi aplikasi berjalan" behavior `DATA_MODEL.md` §2 asks for,
/// with no extra caching code needed.

final class LazyTranslationProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// Lazy translation display for Word Detail (`DATA_MODEL.md` §2 point 4,
  /// `DESIGN_REFERENCE.md` §5.8) — when a meaning's `translation` is
  /// `null`, the student client calls `/translate` and shows the result
  /// **on-screen only**; it is never written back to Firestore (that
  /// distinction lives entirely on the calling side, not in
  /// `AiWorkerService` itself — see its doc comment).
  ///
  /// `@riverpod` (not `.family` manually) already caches per `(word, pos)`
  /// argument pair for the lifetime of the provider container — i.e. for
  /// the rest of the app session — which is exactly the "cache di memori
  /// selama sesi aplikasi berjalan" behavior `DATA_MODEL.md` §2 asks for,
  /// with no extra caching code needed.
  LazyTranslationProvider._({
    required LazyTranslationFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'lazyTranslationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lazyTranslationHash();

  @override
  String toString() {
    return r'lazyTranslationProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    final argument = this.argument as (String, String);
    return lazyTranslation(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is LazyTranslationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lazyTranslationHash() => r'61a7c6e4aca74db488bc6741e321ee6560d6cca8';

/// Lazy translation display for Word Detail (`DATA_MODEL.md` §2 point 4,
/// `DESIGN_REFERENCE.md` §5.8) — when a meaning's `translation` is
/// `null`, the student client calls `/translate` and shows the result
/// **on-screen only**; it is never written back to Firestore (that
/// distinction lives entirely on the calling side, not in
/// `AiWorkerService` itself — see its doc comment).
///
/// `@riverpod` (not `.family` manually) already caches per `(word, pos)`
/// argument pair for the lifetime of the provider container — i.e. for
/// the rest of the app session — which is exactly the "cache di memori
/// selama sesi aplikasi berjalan" behavior `DATA_MODEL.md` §2 asks for,
/// with no extra caching code needed.

final class LazyTranslationFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String>, (String, String)> {
  LazyTranslationFamily._()
    : super(
        retry: null,
        name: r'lazyTranslationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Lazy translation display for Word Detail (`DATA_MODEL.md` §2 point 4,
  /// `DESIGN_REFERENCE.md` §5.8) — when a meaning's `translation` is
  /// `null`, the student client calls `/translate` and shows the result
  /// **on-screen only**; it is never written back to Firestore (that
  /// distinction lives entirely on the calling side, not in
  /// `AiWorkerService` itself — see its doc comment).
  ///
  /// `@riverpod` (not `.family` manually) already caches per `(word, pos)`
  /// argument pair for the lifetime of the provider container — i.e. for
  /// the rest of the app session — which is exactly the "cache di memori
  /// selama sesi aplikasi berjalan" behavior `DATA_MODEL.md` §2 asks for,
  /// with no extra caching code needed.

  LazyTranslationProvider call(String word, String pos) =>
      LazyTranslationProvider._(argument: (word, pos), from: this);

  @override
  String toString() => r'lazyTranslationProvider';
}
