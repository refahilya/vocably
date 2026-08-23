import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_providers.dart';

part 'complete_registration_controller.g.dart';

@riverpod
class CompleteRegistrationController extends _$CompleteRegistrationController {
  @override
  FutureOr<void> build() {}

  /// Completes an orphaned/incomplete Auth account by creating its
  /// `users/{uid}` profile as a default student. This is the only role
  /// this recovery path may ever assign — see DATA_MODEL.md §1 and
  /// the project's explicit "never silently grant guru" decision.
  Future<void> submit({
    required String uid,
    required String email,
    required String name,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref
          .read(userServiceProvider)
          .createStudentProfile(uid: uid, email: email, name: name);
    });
  }
}
