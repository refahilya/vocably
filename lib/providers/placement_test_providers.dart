import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_providers.dart';

part 'placement_test_providers.g.dart';

/// Drives the one write Milestone 6's placement-test scaffold makes:
/// flipping `users.placementTestPrompted` to `true` the moment the
/// one-time automatic offer (`SPEC.md` §3.1) is shown. No scoring, no
/// questions — see `UserService.markPlacementTestPrompted`'s doc comment.
@riverpod
class PlacementTestPromptController extends _$PlacementTestPromptController {
  @override
  FutureOr<void> build() {}

  Future<void> markPrompted(String uid) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(userServiceProvider).markPlacementTestPrompted(uid);
    });
  }
}
