import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/learning_progress.dart';

void main() {
  test('fromFirestore parses a sudahDipelajari/difficult row', () {
    final firstLearnedAt = DateTime(2026, 1, 5);
    final lastUpdatedAt = DateTime(2026, 1, 6);

    final progress = LearningProgress.fromFirestore({
      'studentId': 'student-1',
      'wordId': 'run',
      'learnedStatus': LearnedStatus.sudahDipelajari,
      'masteryStatus': MasteryStatus.difficult,
      'firstLearnedAt': Timestamp.fromDate(firstLearnedAt),
      'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt),
      'lastSessionId': 'session-1',
    });

    expect(progress.studentId, 'student-1');
    expect(progress.wordId, 'run');
    expect(progress.learnedStatus, LearnedStatus.sudahDipelajari);
    expect(progress.masteryStatus, MasteryStatus.difficult);
    expect(progress.firstLearnedAt, firstLearnedAt);
    expect(progress.lastUpdatedAt, lastUpdatedAt);
    expect(progress.lastSessionId, 'session-1');
  });

  test('fromFirestore parses a belumDipelajari row (null mastery/firstLearnedAt)', () {
    final lastUpdatedAt = DateTime(2026, 1, 6);

    final progress = LearningProgress.fromFirestore({
      'studentId': 'student-1',
      'wordId': 'run',
      'learnedStatus': LearnedStatus.belumDipelajari,
      'masteryStatus': null,
      'firstLearnedAt': null,
      'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt),
      'lastSessionId': 'session-1',
    });

    expect(progress.masteryStatus, isNull);
    expect(progress.firstLearnedAt, isNull);
  });
}
