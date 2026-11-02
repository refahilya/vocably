// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'research_panel_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(researchPanelService)
final researchPanelServiceProvider = ResearchPanelServiceProvider._();

final class ResearchPanelServiceProvider
    extends
        $FunctionalProvider<
          ResearchPanelService,
          ResearchPanelService,
          ResearchPanelService
        >
    with $Provider<ResearchPanelService> {
  ResearchPanelServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'researchPanelServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$researchPanelServiceHash();

  @$internal
  @override
  $ProviderElement<ResearchPanelService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ResearchPanelService create(Ref ref) {
    return researchPanelService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResearchPanelService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResearchPanelService>(value),
    );
  }
}

String _$researchPanelServiceHash() =>
    r'd4cf1d651f6690228d39c3aa01fd84c1a112e1ab';

/// Whether [uid] is the active researcher operator (`DATA_MODEL.md` §6d).
/// Live: revoking the record in the tooling removes the panel. This only
/// decides what the app shows; every panel write is re-checked by the rules.

@ProviderFor(researchOperator)
final researchOperatorProvider = ResearchOperatorFamily._();

/// Whether [uid] is the active researcher operator (`DATA_MODEL.md` §6d).
/// Live: revoking the record in the tooling removes the panel. This only
/// decides what the app shows; every panel write is re-checked by the rules.

final class ResearchOperatorProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Whether [uid] is the active researcher operator (`DATA_MODEL.md` §6d).
  /// Live: revoking the record in the tooling removes the panel. This only
  /// decides what the app shows; every panel write is re-checked by the rules.
  ResearchOperatorProvider._({
    required ResearchOperatorFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'researchOperatorProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$researchOperatorHash();

  @override
  String toString() {
    return r'researchOperatorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    final argument = this.argument as String;
    return researchOperator(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ResearchOperatorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$researchOperatorHash() => r'4d15c132c68fd00677b29545086702a5eff5bc10';

/// Whether [uid] is the active researcher operator (`DATA_MODEL.md` §6d).
/// Live: revoking the record in the tooling removes the panel. This only
/// decides what the app shows; every panel write is re-checked by the rules.

final class ResearchOperatorFamily extends $Family
    with $FunctionalFamilyOverride<Stream<bool>, String> {
  ResearchOperatorFamily._()
    : super(
        retry: null,
        name: r'researchOperatorProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether [uid] is the active researcher operator (`DATA_MODEL.md` §6d).
  /// Live: revoking the record in the tooling removes the panel. This only
  /// decides what the app shows; every panel write is re-checked by the rules.

  ResearchOperatorProvider call(String uid) =>
      ResearchOperatorProvider._(argument: uid, from: this);

  @override
  String toString() => r'researchOperatorProvider';
}

/// Live panel data: study windows, participants, roster names, progress
/// mirrors and the latest audit entries, combined once every source has
/// delivered its first value.

@ProviderFor(researchPanelData)
final researchPanelDataProvider = ResearchPanelDataProvider._();

/// Live panel data: study windows, participants, roster names, progress
/// mirrors and the latest audit entries, combined once every source has
/// delivered its first value.

final class ResearchPanelDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<ResearchPanelData>,
          ResearchPanelData,
          Stream<ResearchPanelData>
        >
    with
        $FutureModifier<ResearchPanelData>,
        $StreamProvider<ResearchPanelData> {
  /// Live panel data: study windows, participants, roster names, progress
  /// mirrors and the latest audit entries, combined once every source has
  /// delivered its first value.
  ResearchPanelDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'researchPanelDataProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$researchPanelDataHash();

  @$internal
  @override
  $StreamProviderElement<ResearchPanelData> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ResearchPanelData> create(Ref ref) {
    return researchPanelData(ref);
  }
}

String _$researchPanelDataHash() => r'e054c8f3996772811bf0d22a4f79be6d08b998d2';

/// Runs Researcher Panel actions one at a time for the signed-in operator.

@ProviderFor(ResearchPanelController)
final researchPanelControllerProvider = ResearchPanelControllerFamily._();

/// Runs Researcher Panel actions one at a time for the signed-in operator.
final class ResearchPanelControllerProvider
    extends $NotifierProvider<ResearchPanelController, PanelActionState> {
  /// Runs Researcher Panel actions one at a time for the signed-in operator.
  ResearchPanelControllerProvider._({
    required ResearchPanelControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'researchPanelControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$researchPanelControllerHash();

  @override
  String toString() {
    return r'researchPanelControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ResearchPanelController create() => ResearchPanelController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PanelActionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PanelActionState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ResearchPanelControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$researchPanelControllerHash() =>
    r'3a29d1798eb250c8d65c25eab1579b735589e5d3';

/// Runs Researcher Panel actions one at a time for the signed-in operator.

final class ResearchPanelControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ResearchPanelController,
          PanelActionState,
          PanelActionState,
          PanelActionState,
          String
        > {
  ResearchPanelControllerFamily._()
    : super(
        retry: null,
        name: r'researchPanelControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Runs Researcher Panel actions one at a time for the signed-in operator.

  ResearchPanelControllerProvider call(String operatorUid) =>
      ResearchPanelControllerProvider._(argument: operatorUid, from: this);

  @override
  String toString() => r'researchPanelControllerProvider';
}

/// Runs Researcher Panel actions one at a time for the signed-in operator.

abstract class _$ResearchPanelController extends $Notifier<PanelActionState> {
  late final _$args = ref.$arg as String;
  String get operatorUid => _$args;

  PanelActionState build(String operatorUid);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PanelActionState, PanelActionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PanelActionState, PanelActionState>,
              PanelActionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
