// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authService)
final authServiceProvider = AuthServiceProvider._();

final class AuthServiceProvider
    extends $FunctionalProvider<AuthService, AuthService, AuthService>
    with $Provider<AuthService> {
  AuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authServiceHash();

  @$internal
  @override
  $ProviderElement<AuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthService create(Ref ref) {
    return authService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthService>(value),
    );
  }
}

String _$authServiceHash() => r'ed0872794ec8e4cb3f50cb37b9c0b9467eb51ddb';

@ProviderFor(userService)
final userServiceProvider = UserServiceProvider._();

final class UserServiceProvider
    extends $FunctionalProvider<UserService, UserService, UserService>
    with $Provider<UserService> {
  UserServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userServiceHash();

  @$internal
  @override
  $ProviderElement<UserService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserService create(Ref ref) {
    return userService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserService>(value),
    );
  }
}

String _$userServiceHash() => r'cddff5196a0336b37f300249ff906d557dee36b2';

/// Live Firebase Auth state. Always watched by the root router, so this
/// stays subscribed for the app's whole lifetime in practice.

@ProviderFor(authState)
final authStateProvider = AuthStateProvider._();

/// Live Firebase Auth state. Always watched by the root router, so this
/// stays subscribed for the app's whole lifetime in practice.

final class AuthStateProvider
    extends $FunctionalProvider<AsyncValue<User?>, User?, Stream<User?>>
    with $FutureModifier<User?>, $StreamProvider<User?> {
  /// Live Firebase Auth state. Always watched by the root router, so this
  /// stays subscribed for the app's whole lifetime in practice.
  AuthStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authStateHash();

  @$internal
  @override
  $StreamProviderElement<User?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<User?> create(Ref ref) {
    return authState(ref);
  }
}

String _$authStateHash() => r'f65ef85fe894b530eeed3e3daeaa177f0a63e94c';

/// Live view of the signed-in user's `users/{uid}` profile, or `null` if
/// Firestore has no such document (yet) — see [AppAuthNeedsProfile].
///
/// Deliberately a live listener (`watchProfile`), not a one-shot fetch:
/// right after sign-up (or after completing an orphaned registration) the
/// profile write can land a moment after the first read, and a one-shot
/// fetch would cache that stale `null` forever with nothing to invalidate
/// it. The listener picks up the newly-created document automatically.

@ProviderFor(currentUserProfile)
final currentUserProfileProvider = CurrentUserProfileProvider._();

/// Live view of the signed-in user's `users/{uid}` profile, or `null` if
/// Firestore has no such document (yet) — see [AppAuthNeedsProfile].
///
/// Deliberately a live listener (`watchProfile`), not a one-shot fetch:
/// right after sign-up (or after completing an orphaned registration) the
/// profile write can land a moment after the first read, and a one-shot
/// fetch would cache that stale `null` forever with nothing to invalidate
/// it. The listener picks up the newly-created document automatically.

final class CurrentUserProfileProvider
    extends
        $FunctionalProvider<AsyncValue<AppUser?>, AppUser?, Stream<AppUser?>>
    with $FutureModifier<AppUser?>, $StreamProvider<AppUser?> {
  /// Live view of the signed-in user's `users/{uid}` profile, or `null` if
  /// Firestore has no such document (yet) — see [AppAuthNeedsProfile].
  ///
  /// Deliberately a live listener (`watchProfile`), not a one-shot fetch:
  /// right after sign-up (or after completing an orphaned registration) the
  /// profile write can land a moment after the first read, and a one-shot
  /// fetch would cache that stale `null` forever with nothing to invalidate
  /// it. The listener picks up the newly-created document automatically.
  CurrentUserProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentUserProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentUserProfileHash();

  @$internal
  @override
  $StreamProviderElement<AppUser?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<AppUser?> create(Ref ref) {
    return currentUserProfile(ref);
  }
}

String _$currentUserProfileHash() =>
    r'1126188cb0dad89d18482175a808a9b0affb3466';

@ProviderFor(appAuthStatus)
final appAuthStatusProvider = AppAuthStatusProvider._();

final class AppAuthStatusProvider
    extends $FunctionalProvider<AppAuthStatus, AppAuthStatus, AppAuthStatus>
    with $Provider<AppAuthStatus> {
  AppAuthStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appAuthStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appAuthStatusHash();

  @$internal
  @override
  $ProviderElement<AppAuthStatus> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppAuthStatus create(Ref ref) {
    return appAuthStatus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppAuthStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppAuthStatus>(value),
    );
  }
}

String _$appAuthStatusHash() => r'32e07c599c376b65433e82444cf88d1b4515670a';
