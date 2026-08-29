// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'placement_test_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the one write Milestone 6's placement-test scaffold makes:
/// flipping `users.placementTestPrompted` to `true` the moment the
/// one-time automatic offer (`SPEC.md` §3.1) is shown. No scoring, no
/// questions — see `UserService.markPlacementTestPrompted`'s doc comment.

@ProviderFor(PlacementTestPromptController)
final placementTestPromptControllerProvider =
    PlacementTestPromptControllerProvider._();

/// Drives the one write Milestone 6's placement-test scaffold makes:
/// flipping `users.placementTestPrompted` to `true` the moment the
/// one-time automatic offer (`SPEC.md` §3.1) is shown. No scoring, no
/// questions — see `UserService.markPlacementTestPrompted`'s doc comment.
final class PlacementTestPromptControllerProvider
    extends $AsyncNotifierProvider<PlacementTestPromptController, void> {
  /// Drives the one write Milestone 6's placement-test scaffold makes:
  /// flipping `users.placementTestPrompted` to `true` the moment the
  /// one-time automatic offer (`SPEC.md` §3.1) is shown. No scoring, no
  /// questions — see `UserService.markPlacementTestPrompted`'s doc comment.
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
    r'261468c3fe85e74c50b402ccde0df17f4a20ea7e';

/// Drives the one write Milestone 6's placement-test scaffold makes:
/// flipping `users.placementTestPrompted` to `true` the moment the
/// one-time automatic offer (`SPEC.md` §3.1) is shown. No scoring, no
/// questions — see `UserService.markPlacementTestPrompted`'s doc comment.

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
