// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'complete_registration_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CompleteRegistrationController)
final completeRegistrationControllerProvider =
    CompleteRegistrationControllerProvider._();

final class CompleteRegistrationControllerProvider
    extends $AsyncNotifierProvider<CompleteRegistrationController, void> {
  CompleteRegistrationControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'completeRegistrationControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$completeRegistrationControllerHash();

  @$internal
  @override
  CompleteRegistrationController create() => CompleteRegistrationController();
}

String _$completeRegistrationControllerHash() =>
    r'696be3328fd6ae9194be0bac0c70537ab8426f92';

abstract class _$CompleteRegistrationController extends $AsyncNotifier<void> {
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
