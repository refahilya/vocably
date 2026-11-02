// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'placement_test_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Flips `users.placementTestPrompted` to `true` the moment the one-time
/// automatic offer (`SPEC.md` §3.1) is shown, whatever the student picks.

@ProviderFor(PlacementTestPromptController)
final placementTestPromptControllerProvider =
    PlacementTestPromptControllerProvider._();

/// Flips `users.placementTestPrompted` to `true` the moment the one-time
/// automatic offer (`SPEC.md` §3.1) is shown, whatever the student picks.
final class PlacementTestPromptControllerProvider
    extends $AsyncNotifierProvider<PlacementTestPromptController, void> {
  /// Flips `users.placementTestPrompted` to `true` the moment the one-time
  /// automatic offer (`SPEC.md` §3.1) is shown, whatever the student picks.
  PlacementTestPromptControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'placementTestPromptControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$placementTestPromptControllerHash();

  @$internal
  @override
  PlacementTestPromptController create() => PlacementTestPromptController();
}

String _$placementTestPromptControllerHash() =>
    r'a41ffb7ec8c60ed64b34c4926ef2b30c74847680';

/// Flips `users.placementTestPrompted` to `true` the moment the one-time
/// automatic offer (`SPEC.md` §3.1) is shown, whatever the student picks.

abstract class _$PlacementTestPromptController extends $AsyncNotifier<void> {
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

@ProviderFor(placementService)
final placementServiceProvider = PlacementServiceProvider._();

final class PlacementServiceProvider
    extends
        $FunctionalProvider<
          PlacementService,
          PlacementService,
          PlacementService
        >
    with $Provider<PlacementService> {
  PlacementServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'placementServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$placementServiceHash();

  @$internal
  @override
  $ProviderElement<PlacementService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PlacementService create(Ref ref) {
    return placementService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlacementService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlacementService>(value),
    );
  }
}

String _$placementServiceHash() => r'fafee7d670d5031537ae96af505ce958327830f8';

/// Drives the Placement Test for [uid] (`SPEC.md` §3.1, `DATA_MODEL.md` §6).
///
/// The server is the only source of truth: after any failed or timed-out
/// write the attempt is re-read and the state rebuilt from what is stored.
/// "Terkirim" is shown only after the server holds `submitted`; the result
/// only after the server holds `scored`. Lifecycle signals are recorded and
/// never acted on.

@ProviderFor(PlacementTestController)
final placementTestControllerProvider = PlacementTestControllerFamily._();

/// Drives the Placement Test for [uid] (`SPEC.md` §3.1, `DATA_MODEL.md` §6).
///
/// The server is the only source of truth: after any failed or timed-out
/// write the attempt is re-read and the state rebuilt from what is stored.
/// "Terkirim" is shown only after the server holds `submitted`; the result
/// only after the server holds `scored`. Lifecycle signals are recorded and
/// never acted on.
final class PlacementTestControllerProvider
    extends $NotifierProvider<PlacementTestController, PlacementTestState> {
  /// Drives the Placement Test for [uid] (`SPEC.md` §3.1, `DATA_MODEL.md` §6).
  ///
  /// The server is the only source of truth: after any failed or timed-out
  /// write the attempt is re-read and the state rebuilt from what is stored.
  /// "Terkirim" is shown only after the server holds `submitted`; the result
  /// only after the server holds `scored`. Lifecycle signals are recorded and
  /// never acted on.
  PlacementTestControllerProvider._({
    required PlacementTestControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'placementTestControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$placementTestControllerHash();

  @override
  String toString() {
    return r'placementTestControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PlacementTestController create() => PlacementTestController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlacementTestState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlacementTestState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PlacementTestControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$placementTestControllerHash() =>
    r'd5d54d82c25706cb70c6757ffeaa6a94cc8373cb';

/// Drives the Placement Test for [uid] (`SPEC.md` §3.1, `DATA_MODEL.md` §6).
///
/// The server is the only source of truth: after any failed or timed-out
/// write the attempt is re-read and the state rebuilt from what is stored.
/// "Terkirim" is shown only after the server holds `submitted`; the result
/// only after the server holds `scored`. Lifecycle signals are recorded and
/// never acted on.

final class PlacementTestControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PlacementTestController,
          PlacementTestState,
          PlacementTestState,
          PlacementTestState,
          String
        > {
  PlacementTestControllerFamily._()
    : super(
        retry: null,
        name: r'placementTestControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Drives the Placement Test for [uid] (`SPEC.md` §3.1, `DATA_MODEL.md` §6).
  ///
  /// The server is the only source of truth: after any failed or timed-out
  /// write the attempt is re-read and the state rebuilt from what is stored.
  /// "Terkirim" is shown only after the server holds `submitted`; the result
  /// only after the server holds `scored`. Lifecycle signals are recorded and
  /// never acted on.

  PlacementTestControllerProvider call(String uid) =>
      PlacementTestControllerProvider._(argument: uid, from: this);

  @override
  String toString() => r'placementTestControllerProvider';
}

/// Drives the Placement Test for [uid] (`SPEC.md` §3.1, `DATA_MODEL.md` §6).
///
/// The server is the only source of truth: after any failed or timed-out
/// write the attempt is re-read and the state rebuilt from what is stored.
/// "Terkirim" is shown only after the server holds `submitted`; the result
/// only after the server holds `scored`. Lifecycle signals are recorded and
/// never acted on.

abstract class _$PlacementTestController extends $Notifier<PlacementTestState> {
  late final _$args = ref.$arg as String;
  String get uid => _$args;

  PlacementTestState build(String uid);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PlacementTestState, PlacementTestState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlacementTestState, PlacementTestState>,
              PlacementTestState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
