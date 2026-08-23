import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

part 'auth_providers.g.dart';

@riverpod
AuthService authService(Ref ref) => AuthService();

@riverpod
UserService userService(Ref ref) => UserService();

/// Live Firebase Auth state. Always watched by the root router, so this
/// stays subscribed for the app's whole lifetime in practice.
@riverpod
Stream<User?> authState(Ref ref) {
  return ref.watch(authServiceProvider).authStateChanges();
}

/// Live view of the signed-in user's `users/{uid}` profile, or `null` if
/// Firestore has no such document (yet) — see [AppAuthNeedsProfile].
///
/// Deliberately a live listener (`watchProfile`), not a one-shot fetch:
/// right after sign-up (or after completing an orphaned registration) the
/// profile write can land a moment after the first read, and a one-shot
/// fetch would cache that stale `null` forever with nothing to invalidate
/// it. The listener picks up the newly-created document automatically.
@riverpod
Stream<AppUser?> currentUserProfile(Ref ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(userServiceProvider).watchProfile(user.uid);
}

/// Combined status the root routing widget (`app.dart`) switches on.
sealed class AppAuthStatus {
  const AppAuthStatus();
}

class AppAuthLoading extends AppAuthStatus {
  const AppAuthLoading();
}

class AppAuthSignedOut extends AppAuthStatus {
  const AppAuthSignedOut();
}

/// Auth succeeded but `users/{uid}` doesn't exist. Either a genuinely
/// orphaned account, or the brief moment before a fresh sign-up's profile
/// write settles. The UI offers to complete registration as a default
/// `siswa` — it must never silently grant `guru` (see
/// CompleteRegistrationController).
class AppAuthNeedsProfile extends AppAuthStatus {
  const AppAuthNeedsProfile({required this.uid, required this.email});
  final String uid;
  final String email;
}

class AppAuthSignedIn extends AppAuthStatus {
  const AppAuthSignedIn(this.profile);
  final AppUser profile;
}

@riverpod
AppAuthStatus appAuthStatus(Ref ref) {
  final authAsync = ref.watch(authStateProvider);

  return authAsync.when(
    loading: () => const AppAuthLoading(),
    error: (_, _) => const AppAuthSignedOut(),
    data: (user) {
      if (user == null) return const AppAuthSignedOut();

      final profileAsync = ref.watch(currentUserProfileProvider);
      return profileAsync.when(
        loading: () => const AppAuthLoading(),
        error: (_, _) =>
            AppAuthNeedsProfile(uid: user.uid, email: user.email ?? ''),
        data: (profile) => profile == null
            ? AppAuthNeedsProfile(uid: user.uid, email: user.email ?? '')
            : AppAuthSignedIn(profile),
      );
    },
  );
}
