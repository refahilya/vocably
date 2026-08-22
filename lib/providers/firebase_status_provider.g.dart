// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reports whether Firebase (`firebase_core`, with `firebase_auth` and
/// `cloud_firestore` confirmed configured) initialized successfully.
///
/// This is also the Milestone 1 proof that the Riverpod code-generation
/// pipeline (build_runner + riverpod_generator) works end-to-end.

@ProviderFor(FirebaseStatusNotifier)
final firebaseStatusProvider = FirebaseStatusNotifierProvider._();

/// Reports whether Firebase (`firebase_core`, with `firebase_auth` and
/// `cloud_firestore` confirmed configured) initialized successfully.
///
/// This is also the Milestone 1 proof that the Riverpod code-generation
/// pipeline (build_runner + riverpod_generator) works end-to-end.
final class FirebaseStatusNotifierProvider
    extends $AsyncNotifierProvider<FirebaseStatusNotifier, FirebaseStatus> {
  /// Reports whether Firebase (`firebase_core`, with `firebase_auth` and
  /// `cloud_firestore` confirmed configured) initialized successfully.
  ///
  /// This is also the Milestone 1 proof that the Riverpod code-generation
  /// pipeline (build_runner + riverpod_generator) works end-to-end.
  FirebaseStatusNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firebaseStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firebaseStatusNotifierHash();

  @$internal
  @override
  FirebaseStatusNotifier create() => FirebaseStatusNotifier();
}

String _$firebaseStatusNotifierHash() =>
    r'4de6f7298c4ff9e381865e5a5d733fecfe9f4557';

/// Reports whether Firebase (`firebase_core`, with `firebase_auth` and
/// `cloud_firestore` confirmed configured) initialized successfully.
///
/// This is also the Milestone 1 proof that the Riverpod code-generation
/// pipeline (build_runner + riverpod_generator) works end-to-end.

abstract class _$FirebaseStatusNotifier extends $AsyncNotifier<FirebaseStatus> {
  FutureOr<FirebaseStatus> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<FirebaseStatus>, FirebaseStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<FirebaseStatus>, FirebaseStatus>,
              AsyncValue<FirebaseStatus>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
