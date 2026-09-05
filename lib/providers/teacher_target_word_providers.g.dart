// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher_target_word_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// All target word sets created by [teacherId], sorted in memory by
/// `createdAt` descending (`DATA_MODEL.md` §5).

@ProviderFor(teacherTargetWordSets)
final teacherTargetWordSetsProvider = TeacherTargetWordSetsFamily._();

/// All target word sets created by [teacherId], sorted in memory by
/// `createdAt` descending (`DATA_MODEL.md` §5).

final class TeacherTargetWordSetsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TargetWordSet>>,
          List<TargetWordSet>,
          FutureOr<List<TargetWordSet>>
        >
    with
        $FutureModifier<List<TargetWordSet>>,
        $FutureProvider<List<TargetWordSet>> {
  /// All target word sets created by [teacherId], sorted in memory by
  /// `createdAt` descending (`DATA_MODEL.md` §5).
  TeacherTargetWordSetsProvider._({
    required TeacherTargetWordSetsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'teacherTargetWordSetsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$teacherTargetWordSetsHash();

  @override
  String toString() {
    return r'teacherTargetWordSetsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TargetWordSet>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TargetWordSet>> create(Ref ref) {
    final argument = this.argument as String;
    return teacherTargetWordSets(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TeacherTargetWordSetsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$teacherTargetWordSetsHash() =>
    r'569f45f4a49682eb3523d45517279995da90c911';

/// All target word sets created by [teacherId], sorted in memory by
/// `createdAt` descending (`DATA_MODEL.md` §5).

final class TeacherTargetWordSetsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TargetWordSet>>, String> {
  TeacherTargetWordSetsFamily._()
    : super(
        retry: null,
        name: r'teacherTargetWordSetsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// All target word sets created by [teacherId], sorted in memory by
  /// `createdAt` descending (`DATA_MODEL.md` §5).

  TeacherTargetWordSetsProvider call(String teacherId) =>
      TeacherTargetWordSetsProvider._(argument: teacherId, from: this);

  @override
  String toString() => r'teacherTargetWordSetsProvider';
}

/// Drives the guru "Set Target Kata" write flow (Milestone 8, `SPEC.md` §4.1).

@ProviderFor(SetTargetWordController)
final setTargetWordControllerProvider = SetTargetWordControllerProvider._();

/// Drives the guru "Set Target Kata" write flow (Milestone 8, `SPEC.md` §4.1).
final class SetTargetWordControllerProvider
    extends $AsyncNotifierProvider<SetTargetWordController, void> {
  /// Drives the guru "Set Target Kata" write flow (Milestone 8, `SPEC.md` §4.1).
  SetTargetWordControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'setTargetWordControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$setTargetWordControllerHash();

  @$internal
  @override
  SetTargetWordController create() => SetTargetWordController();
}

String _$setTargetWordControllerHash() =>
    r'db181b9dc33d4fb9ca520c4a434733c75b439973';

/// Drives the guru "Set Target Kata" write flow (Milestone 8, `SPEC.md` §4.1).

abstract class _$SetTargetWordController extends $AsyncNotifier<void> {
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
