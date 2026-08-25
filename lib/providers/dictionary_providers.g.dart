// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(dictionaryApiService)
final dictionaryApiServiceProvider = DictionaryApiServiceProvider._();

final class DictionaryApiServiceProvider
    extends
        $FunctionalProvider<
          DictionaryApiService,
          DictionaryApiService,
          DictionaryApiService
        >
    with $Provider<DictionaryApiService> {
  DictionaryApiServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dictionaryApiServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dictionaryApiServiceHash();

  @$internal
  @override
  $ProviderElement<DictionaryApiService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DictionaryApiService create(Ref ref) {
    return dictionaryApiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DictionaryApiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DictionaryApiService>(value),
    );
  }
}

String _$dictionaryApiServiceHash() =>
    r'7d3b84d82e3b7098128745242ae5aa16fc4f2cfa';

@ProviderFor(ttsService)
final ttsServiceProvider = TtsServiceProvider._();

final class TtsServiceProvider
    extends $FunctionalProvider<TtsService, TtsService, TtsService>
    with $Provider<TtsService> {
  TtsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ttsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ttsServiceHash();

  @$internal
  @override
  $ProviderElement<TtsService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TtsService create(Ref ref) {
    return ttsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TtsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TtsService>(value),
    );
  }
}

String _$ttsServiceHash() => r'29bea7909c95b01ab8969e1d895e6b40dbbb40bb';

/// One lookup per normalized word — a family provider so opening the same
/// word twice in a session (e.g. back out of the detail screen, tap it
/// again) doesn't re-hit the API, matching `SPEC.md` §3.5's "boleh
/// di-cache di memori selama sesi aplikasi berjalan supaya tidak dipanggil
/// berulang" (written there for the Indonesian `/translate` lazy-display
/// call, but the same reasoning applies here). Not `keepAlive` — once
/// nothing is watching a given word anymore (detail screen popped, and
/// the user never reopens it), Riverpod disposes it like any other
/// `FutureProvider`, so this doesn't grow into an unbounded in-memory
/// cache over a long session.

@ProviderFor(dictionaryLookup)
final dictionaryLookupProvider = DictionaryLookupFamily._();

/// One lookup per normalized word — a family provider so opening the same
/// word twice in a session (e.g. back out of the detail screen, tap it
/// again) doesn't re-hit the API, matching `SPEC.md` §3.5's "boleh
/// di-cache di memori selama sesi aplikasi berjalan supaya tidak dipanggil
/// berulang" (written there for the Indonesian `/translate` lazy-display
/// call, but the same reasoning applies here). Not `keepAlive` — once
/// nothing is watching a given word anymore (detail screen popped, and
/// the user never reopens it), Riverpod disposes it like any other
/// `FutureProvider`, so this doesn't grow into an unbounded in-memory
/// cache over a long session.

final class DictionaryLookupProvider
    extends
        $FunctionalProvider<
          AsyncValue<DictionaryLookupResult>,
          DictionaryLookupResult,
          FutureOr<DictionaryLookupResult>
        >
    with
        $FutureModifier<DictionaryLookupResult>,
        $FutureProvider<DictionaryLookupResult> {
  /// One lookup per normalized word — a family provider so opening the same
  /// word twice in a session (e.g. back out of the detail screen, tap it
  /// again) doesn't re-hit the API, matching `SPEC.md` §3.5's "boleh
  /// di-cache di memori selama sesi aplikasi berjalan supaya tidak dipanggil
  /// berulang" (written there for the Indonesian `/translate` lazy-display
  /// call, but the same reasoning applies here). Not `keepAlive` — once
  /// nothing is watching a given word anymore (detail screen popped, and
  /// the user never reopens it), Riverpod disposes it like any other
  /// `FutureProvider`, so this doesn't grow into an unbounded in-memory
  /// cache over a long session.
  DictionaryLookupProvider._({
    required DictionaryLookupFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'dictionaryLookupProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dictionaryLookupHash();

  @override
  String toString() {
    return r'dictionaryLookupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<DictionaryLookupResult> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DictionaryLookupResult> create(Ref ref) {
    final argument = this.argument as String;
    return dictionaryLookup(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DictionaryLookupProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dictionaryLookupHash() => r'638e885c0582ab2bf1118885070333233ad14245';

/// One lookup per normalized word — a family provider so opening the same
/// word twice in a session (e.g. back out of the detail screen, tap it
/// again) doesn't re-hit the API, matching `SPEC.md` §3.5's "boleh
/// di-cache di memori selama sesi aplikasi berjalan supaya tidak dipanggil
/// berulang" (written there for the Indonesian `/translate` lazy-display
/// call, but the same reasoning applies here). Not `keepAlive` — once
/// nothing is watching a given word anymore (detail screen popped, and
/// the user never reopens it), Riverpod disposes it like any other
/// `FutureProvider`, so this doesn't grow into an unbounded in-memory
/// cache over a long session.

final class DictionaryLookupFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<DictionaryLookupResult>, String> {
  DictionaryLookupFamily._()
    : super(
        retry: null,
        name: r'dictionaryLookupProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One lookup per normalized word — a family provider so opening the same
  /// word twice in a session (e.g. back out of the detail screen, tap it
  /// again) doesn't re-hit the API, matching `SPEC.md` §3.5's "boleh
  /// di-cache di memori selama sesi aplikasi berjalan supaya tidak dipanggil
  /// berulang" (written there for the Indonesian `/translate` lazy-display
  /// call, but the same reasoning applies here). Not `keepAlive` — once
  /// nothing is watching a given word anymore (detail screen popped, and
  /// the user never reopens it), Riverpod disposes it like any other
  /// `FutureProvider`, so this doesn't grow into an unbounded in-memory
  /// cache over a long session.

  DictionaryLookupProvider call(String word) =>
      DictionaryLookupProvider._(argument: word, from: this);

  @override
  String toString() => r'dictionaryLookupProvider';
}
