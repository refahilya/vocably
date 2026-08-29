import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/target_word_set.dart';
import 'package:vocably/services/target_word_set_service.dart';

TargetWordSet _set({required String id, required DateTime startAt}) {
  return TargetWordSet(
    id: id,
    teacherId: 'teacher-1',
    wordIds: const ['run'],
    cefrLevel: 'A2',
    startAt: startAt,
    endAt: DateTime(2099, 12, 31),
    targetStudentIds: const ['__all__'],
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  // filterStillActive is the client-side half of DATA_MODEL.md §5's query
  // (the server-side `endAt` filter/index is exercised only by manual
  // verification against the real project — see PROJECT_STATE.md; no
  // Firestore fake/emulator exists in this repo, same disclosed gap as
  // VocabWordService/TopicsService).
  group('filterStillActive', () {
    final now = DateTime(2026, 6, 15);

    test('keeps a set whose startAt has already passed', () {
      final set = _set(id: 'past', startAt: DateTime(2026, 1, 1));
      expect(filterStillActive([set], now), [set]);
    });

    test('keeps a set whose startAt is exactly now', () {
      final set = _set(id: 'exact', startAt: now);
      expect(filterStillActive([set], now), [set]);
    });

    test('drops a set whose startAt is still in the future', () {
      final set = _set(id: 'future', startAt: DateTime(2026, 12, 1));
      expect(filterStillActive([set], now), isEmpty);
    });

    test('filters a mixed list, preserving order', () {
      final active = _set(id: 'active', startAt: DateTime(2026, 1, 1));
      final future = _set(id: 'future', startAt: DateTime(2027, 1, 1));
      final alsoActive = _set(id: 'also-active', startAt: DateTime(2026, 6, 1));

      expect(filterStillActive([active, future, alsoActive], now), [active, alsoActive]);
    });

    test('empty input returns empty output', () {
      expect(filterStillActive(const [], now), isEmpty);
    });
  });
}
