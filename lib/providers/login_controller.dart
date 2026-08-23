import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_providers.dart';

part 'login_controller.g.dart';

@riverpod
class LoginController extends _$LoginController {
  @override
  FutureOr<void> build() {}

  Future<void> submit({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(authServiceProvider).signIn(email: email, password: password);
    });
  }
}
