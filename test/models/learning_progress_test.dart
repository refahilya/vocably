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

  group('Milestone 7 write-side helpers', () {
    test('docId is exactly {studentId}_{wordId}', () {
      expect(
        LearningProgress.docId(studentId: 'student-1', wordId: 'run'),
        'student-1_run',
      );
      // Multi-word phrases keep their internal space, same as
      // normalizeWord()'s own convention.
      expect(
        LearningProgress.docId(studentId: 'student-1', wordId: 'wake up'),
        'student-1_wake up',
      );
    });

    test('newLearnedData always starts sudahDipelajari with the given masteryStatus', () {
      final data = LearningProgress.newLearnedData(
        studentId: 'student-1',
        wordId: 'run',
        masteryStatus: MasteryStatus.difficult,
        lastSessionId: 'session-1',
      );

      expect(data['studentId'], 'student-1');
      expect(data['wordId'], 'run');
      expect(data['learnedStatus'], LearnedStatus.sudahDipelajari);
      expect(data['masteryStatus'], MasteryStatus.difficult);
      expect(data['lastSessionId'], 'session-1');
      expect(data.containsKey('firstLearnedAt'), isTrue);
      expect(data.containsKey('lastUpdatedAt'), isTrue);
    });

    test('touchData without masteryStatus only refreshes bookkeeping fields', () {
      final data = LearningProgress.touchData(lastSessionId: 'session-2');

      expect(data.keys.toSet(), {'lastUpdatedAt', 'lastSessionId'});
      expect(data['lastSessionId'], 'session-2');
    });

    test('touchData with masteryStatus includes the upgrade', () {
      final data = LearningProgress.touchData(
        lastSessionId: 'session-2',
        masteryStatus: MasteryStatus.mastered,
      );

      expect(data.keys.toSet(), {'lastUpdatedAt', 'lastSessionId', 'masteryStatus'});
      expect(data['masteryStatus'], MasteryStatus.mastered);
    });
  });
}
