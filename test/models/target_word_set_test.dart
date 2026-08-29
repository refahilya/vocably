import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/target_word_set.dart';

void main() {
  test('fromFirestore parses every field', () {
    final startAt = DateTime(2026, 1, 1);
    final endAt = DateTime(2026, 12, 31);
    final createdAt = DateTime(2025, 12, 1);

    final set = TargetWordSet.fromFirestore('set-1', {
      'teacherId': 'teacher-1',
      'wordIds': ['run', 'souvenir'],
      'cefrLevel': 'A2',
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'targetStudentIds': ['__all__'],
      'createdAt': Timestamp.fromDate(createdAt),
    });

    expect(set.id, 'set-1');
    expect(set.teacherId, 'teacher-1');
    expect(set.wordIds, ['run', 'souvenir']);
    expect(set.cefrLevel, 'A2');
    expect(set.startAt, startAt);
    expect(set.endAt, endAt);
    expect(set.targetStudentIds, ['__all__']);
    expect(set.createdAt, createdAt);
  });
}
