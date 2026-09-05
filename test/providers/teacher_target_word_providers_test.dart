import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/target_word_set.dart';
import 'package:vocably/providers/dashboard_providers.dart';
import 'package:vocably/providers/teacher_target_word_providers.dart';
import 'package:vocably/services/target_word_set_service.dart';

class _FakeTargetWordSetService extends TargetWordSetService {
  List<TargetWordSet> sets = [];
  bool shouldThrow = false;
  String? createdTeacherId;
  List<String>? createdWordIds;
  String? createdCefrLevel;
  DateTime? createdStartAt;
  DateTime? createdEndAt;

  @override
  Future<List<TargetWordSet>> fetchForTeacher(String teacherId) async {
    if (shouldThrow) throw Exception('simulated failure');
    return sets.where((s) => s.teacherId == teacherId).toList();
  }

  @override
  Future<String> createTargetWordSet({
    required String teacherId,
    required List<String> wordIds,
    required String cefrLevel,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    if (shouldThrow) throw Exception('simulated failure');
    createdTeacherId = teacherId;
    createdWordIds = wordIds;
    createdCefrLevel = cefrLevel;
    createdStartAt = startAt;
    createdEndAt = endAt;
    final newSet = TargetWordSet(
      id: 'set-${sets.length + 1}',
      teacherId: teacherId,
      wordIds: wordIds,
      cefrLevel: cefrLevel,
      startAt: startAt,
      endAt: endAt,
      targetStudentIds: const ['__all__'],
      createdAt: DateTime.now(),
    );
    sets = [...sets, newSet];
    return newSet.id;
  }
}

void main() {
  group('teacherTargetWordSetsProvider', () {
    test('fetches and sorts target sets by createdAt descending', () async {
      final fakeService = _FakeTargetWordSetService()
        ..sets = [
          TargetWordSet(
            id: 'older',
            teacherId: 'teacher-1',
            wordIds: const ['apple'],
            cefrLevel: 'A1',
            startAt: DateTime(2026, 1, 1),
            endAt: DateTime(2026, 1, 10),
            targetStudentIds: const ['__all__'],
            createdAt: DateTime(2026, 1, 1),
          ),
          TargetWordSet(
            id: 'newer',
            teacherId: 'teacher-1',
            wordIds: const ['banana'],
            cefrLevel: 'A1',
            startAt: DateTime(2026, 2, 1),
            endAt: DateTime(2026, 2, 10),
            targetStudentIds: const ['__all__'],
            createdAt: DateTime(2026, 2, 1),
          ),
        ];

      final container = ProviderContainer(
        overrides: [
          targetWordSetServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(teacherTargetWordSetsProvider('teacher-1').future);

      expect(result.map((s) => s.id), ['newer', 'older']);
    });
  });

  group('SetTargetWordController', () {
    test('createTargetWordSet invokes service with correct arguments', () async {
      final fakeService = _FakeTargetWordSetService();
      final container = ProviderContainer(
        overrides: [
          targetWordSetServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 9, 5, 23, 59, 59);

      final id = await container.read(setTargetWordControllerProvider.notifier).createTargetWordSet(
        teacherId: 'teacher-1',
        wordIds: ['apple', 'banana'],
        cefrLevel: 'A1',
        startAt: start,
        endAt: end,
      );

      expect(id, isNotNull);
      expect(fakeService.createdTeacherId, 'teacher-1');
      expect(fakeService.createdWordIds, ['apple', 'banana']);
      expect(fakeService.createdCefrLevel, 'A1');
      expect(fakeService.createdStartAt, start);
      expect(fakeService.createdEndAt, end);
    });

    test('sets error state when createTargetWordSet throws', () async {
      final fakeService = _FakeTargetWordSetService()..shouldThrow = true;
      final container = ProviderContainer(
        overrides: [
          targetWordSetServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(setTargetWordControllerProvider.notifier).createTargetWordSet(
        teacherId: 'teacher-1',
        wordIds: ['apple'],
        cefrLevel: 'A1',
        startAt: DateTime.now(),
        endAt: DateTime.now(),
      );

      final state = container.read(setTargetWordControllerProvider);
      expect(state.hasError, isTrue);
    });
  });
}
