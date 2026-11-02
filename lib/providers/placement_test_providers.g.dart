// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'placement_test_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Flips `users.placementTestPrompted` to `true` the moment the one-time
/// automatic offer (`SPEC.md` §3.1) is shown, whatever the student picks.
///
/// Kept alive per student: the write's local snapshot takes the offer off
/// screen before the server answers, and a refusal rolls that snapshot back
/// and brings the offer back. The failure has to outlive the offer screen in
/// between so the returning offer can say why it is there again.

@ProviderFor(PlacementTestPromptController)
final placementTestPromptControllerProvider =
    PlacementTestPromptControllerFamily._();

/// Flips `users.placementTestPrompted` to `true` the moment the one-time
/// automatic offer (`SPEC.md` §3.1) is shown, whatever the student picks.
///
/// Kept alive per student: the write's local snapshot takes the offer off
/// screen before the server answers, and a refusal rolls that snapshot back
/// and brings the offer back. The failure has to outlive the offer screen in
/// between so the returning offer can say why it is there again.
final class PlacementTestPromptControllerProvider
    extends $AsyncNotifierProvider<PlacementTestPromptController, void> {
  /// Flips `users.placementTestPrompted` to `true` the moment the one-time
  /// automatic offer (`SPEC.md` §3.1) is shown, whatever the student picks.
  ///
  /// Kept alive per student: the write's local snapshot takes the offer off
  /// screen before the server answers, and a refusal rolls that snapshot back
  /// and brings the offer back. The failure has to outlive the offer screen in
  /// between so the returning offer can say why it is there again.
  PlacementTestPromptControllerProvider._({
    required PlacementTestPromptControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'placementTestPromptControllerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$placementTestPromptControllerHash();

  @override
  String toString() {
    return r'placementTestPromptControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PlacementTestPromptController create() => PlacementTestPromptController();

  @override
  bool operator ==(Object other) {
    return other is PlacementTestPromptControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$placementTestPromptControllerHash() =>
    r'fa436bc8128505dba3cd24de50774129f5b316d0';

/// Flips `users.placementTestPrompted` to `true` the moment the one-time
/// automatic offer (`SPEC.md` §3.1) is shown, whatever the student picks.
///
/// Kept alive per student: the write's local snapshot takes the offer off
/// screen before the server answers, and a refusal rolls that snapshot back
/// and brings the offer back. The failure has to outlive the offer screen in
/// between so the returning offer can say why it is there again.

final class PlacementTestPromptControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PlacementTestPromptController,
          AsyncValue<void>,
          void,
          FutureOr<void>,
          String
        > {
  PlacementTestPromptControllerFamily._()
    : super(
        retry: null,
        name: r'placementTestPromptControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Flips `users.placementTestPrompted` to `true` the moment the one-time
  /// automatic offer (`SPEC.md` §3.1) is shown, whatever the student picks.
  ///
  /// Kept alive per student: the write's local snapshot takes the offer off
  /// screen before the server answers, and a refusal rolls that snapshot back
  /// and brings the offer back. The failure has to outlive the offer screen in
  /// between so the returning offer can say why it is there again.

  PlacementTestPromptControllerProvider call(String uid) =>
      PlacementTestPromptControllerProvider._(argument: uid, from: this);

  @override
  String toString() => r'placementTestPromptControllerProvider';
}

/// Flips `users.placementTestPrompted` to `true` the moment the one-time
/// automatic offer (`SPEC.md` §3.1) is shown, whatever the student picks.
///
/// Kept alive per student: the write's local snapshot takes the offer off
/// screen before the server answers, and a refusal rolls that snapshot back
/// and brings the offer back. The failure has to outlive the offer screen in
/// between so the returning offer can say why it is there again.

abstract class _$PlacementTestPromptController extends $AsyncNotifier<void> {
  late final _$args = ref.$arg as String;
  String get uid => _$args;

  FutureOr<void> build(String uid);
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
    return element.handleCreate(ref, () => build(_$args));
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
    r'a5d2c5f564eb470b869bd3f321d08afb47b78651';

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
