import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_providers.dart';

part 'sign_up_controller.g.dart';

/// Thrown when a teacher sign-up's access code is confirmed invalid by
/// Security Rules. The UI shows this as "Kode akses tidak valid".
class InvalidTeacherCodeException implements Exception {
  const InvalidTeacherCodeException();
}

@riverpod
class SignUpController extends _$SignUpController {
  @override
  FutureOr<void> build() {}

  /// Runs sign-up as one flow: create the Auth account, then create the
  /// matching Firestore profile.
  ///
  /// - Teacher branch of the `users` create rule is the only conditional
  ///   branch (the student branch is an unconditional allow), so a
  ///   `permission-denied` on a teacher-flagged attempt can only mean the
  ///   access code was invalid/inactive. In that case — and only that
  ///   case — the just-created Auth account is deleted (no orphaned
  ///   account) and [InvalidTeacherCodeException] is thrown.
  /// - Any other failure (network drop, Firestore temporarily
  ///   unavailable, etc.) is NOT assumed to mean the write definitely
  ///   failed, so the Auth account is deliberately left alone. The user
  ///   ends up signed in without a profile; the root router's "complete
  ///   your registration" recovery screen (siswa-only) takes over from
  ///   there instead of this controller guessing at an unconfirmed
  ///   outcome.
  Future<void> submit({
    required String email,
    required String password,
    required String name,
    required bool asTeacher,
    String? teacherCode,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authService = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);

      final credential = await authService.signUp(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;

      try {
        if (asTeacher) {
          await userService.createTeacherProfile(
            uid: uid,
            email: email,
            name: name,
            teacherCodeInput: teacherCode!,
          );
        } else {
          await userService.createStudentProfile(
            uid: uid,
            email: email,
            name: name,
          );
        }
      } on FirebaseException catch (e) {
        if (asTeacher && e.code == 'permission-denied') {
          await authService.deleteCurrentUser();
          throw const InvalidTeacherCodeException();
        }
        rethrow;
      }
    });
  }
}
