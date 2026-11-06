import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/target_word_set.dart';
import 'dashboard_providers.dart';

part 'teacher_target_word_providers.g.dart';

/// All target word sets created by [teacherId], sorted in memory by
/// `createdAt` descending (`DATA_MODEL.md` §5). Official research session
/// sets (`DATA_MODEL.md` §6e) are managed in the Researcher Panel and left
/// out here.
@riverpod
Future<List<TargetWordSet>> teacherTargetWordSets(
  Ref ref,
  String teacherId,
) async {
  final sets = await ref
      .watch(targetWordSetServiceProvider)
      .fetchForTeacher(teacherId);
  final sorted = [for (final set in sets) if (!set.isResearch) set];
  sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted;
}

/// Drives the guru "Set Target Kata" write flow (Milestone 8, `SPEC.md` §4.1).
@riverpod
class SetTargetWordController extends _$SetTargetWordController {
  @override
  FutureOr<void> build() {}

  /// Creates a brand-new target word set for [teacherId].
  Future<String?> createTargetWordSet({
    required String teacherId,
    required List<String> wordIds,
    required String cefrLevel,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    state = const AsyncLoading();
    String? createdId;
    state = await AsyncValue.guard(() async {
      final service = ref.read(targetWordSetServiceProvider);
      createdId = await service.createTargetWordSet(
        teacherId: teacherId,
        wordIds: wordIds,
        cefrLevel: cefrLevel,
        startAt: startAt,
        endAt: endAt,
      );
      ref.invalidate(teacherTargetWordSetsProvider(teacherId));
    });
    return createdId;
  }
}
