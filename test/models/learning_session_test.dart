import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/learning_session.dart';

void main() {
  test('fromFirestore parses a completed session with a full transcript', () {
    final startedAt = DateTime(2026, 8, 1, 10, 0);
    final completedAt = DateTime(2026, 8, 1, 10, 30);

    final session = LearningSession.fromFirestore('session-1', {
      'studentId': 'student-1',
      'wordIds': ['run', 'souvenir'],
      'sourceType': LearningSessionSourceType.keranjangPelajari,
      'currentPhase': LearningSessionPhase.selesai,
      'storyTitle': 'Liburan',
      'storyContent': 'I [[run|ran]] and bought a [[souvenir|souvenir]].',
      'storyTranslation': 'Saya berlari dan membeli oleh-oleh.',
      'clozeTestResult': {'run': true, 'souvenir': false},
      'cowriteTranscript': [
        {
          'sender': 'siswa',
          'text': 'I ran fast.',
          'feedback': null,
          'usedSuggestion': false,
        },
      ],
      'cowriteWordsUsedCorrectly': ['run'],
      'startedAt': Timestamp.fromDate(startedAt),
      'completedAt': Timestamp.fromDate(completedAt),
    });

    expect(session.id, 'session-1');
    expect(session.studentId, 'student-1');
    expect(session.wordIds, ['run', 'souvenir']);
    expect(session.sourceType, LearningSessionSourceType.keranjangPelajari);
    expect(session.currentPhase, LearningSessionPhase.selesai);
    expect(session.storyTitle, 'Liburan');
    expect(session.clozeTestResult, {'run': true, 'souvenir': false});
    expect(session.cowriteTranscript, hasLength(1));
    expect(session.cowriteTranscript.single.sender, 'siswa');
    expect(session.cowriteTranscript.single.usedSuggestion, isFalse);
    expect(session.cowriteWordsUsedCorrectly, ['run']);
    expect(session.startedAt, startedAt);
    expect(session.completedAt, completedAt);
  });

  test('fromFirestore handles an in-progress session (null completedAt, empty maps)', () {
    final startedAt = DateTime(2026, 8, 1, 10, 0);

    final session = LearningSession.fromFirestore('session-2', {
      'studentId': 'student-1',
      'wordIds': ['run'],
      'sourceType': LearningSessionSourceType.targetGuru,
      'currentPhase': LearningSessionPhase.membaca,
      'storyTitle': 'Liburan',
      'storyContent': 'I [[run|run]] every day.',
      'storyTranslation': null,
      'clozeTestResult': <String, dynamic>{},
      'cowriteTranscript': null,
      'cowriteWordsUsedCorrectly': null,
      'startedAt': Timestamp.fromDate(startedAt),
      'completedAt': null,
    });

    expect(session.storyTranslation, isNull);
    expect(session.clozeTestResult, isEmpty);
    expect(session.cowriteTranscript, isEmpty);
    expect(session.cowriteWordsUsedCorrectly, isEmpty);
    expect(session.completedAt, isNull);
  });

  group('fromFirestore — malformed documents fail loudly and diagnosably', () {
    // Regression coverage for a real bug found via manual testing: a
    // document with `wordIds: null` used to throw a bare `TypeError`
    // ("null: type 'Null' is not a subtype of type 'List<dynamic>'")
    // with nothing but a line number to go on — no document id, no field
    // name. `LearningSessionService.fetchForStudent` queries by
    // `studentId` alone (no `docId` filter), so more than one document
    // can be in play; not naming the failing one made this undiagnosable
    // from a running app. `wordIds` is deliberately treated as required
    // (not defaulted to `[]`) — DATA_MODEL.md §4 doesn't mark it
    // nullable, and it's populated from the very first write of a
    // session document, unlike `cowriteTranscript`/
    // `cowriteWordsUsedCorrectly`/`clozeTestResult` (see the fixture
    // above), which legitimately start empty for an early-phase session.
    Map<String, dynamic> validData() => {
      'studentId': 'student-1',
      'wordIds': ['run'],
      'sourceType': LearningSessionSourceType.keranjangPelajari,
      'currentPhase': LearningSessionPhase.membaca,
      'storyTitle': 'Liburan',
      'storyContent': 'I [[run|run]] today.',
      'storyTranslation': null,
      'clozeTestResult': <String, dynamic>{},
      'cowriteTranscript': <dynamic>[],
      'cowriteWordsUsedCorrectly': <dynamic>[],
      'startedAt': Timestamp.fromDate(DateTime(2026, 8, 1)),
      'completedAt': null,
    };

    test('wordIds: null names the exact document id and field, not a bare TypeError', () {
      final data = validData()..['wordIds'] = null;

      expect(
        () => LearningSession.fromFirestore('test-session', data),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('learningSessions/test-session'), contains('"wordIds"')),
          ),
        ),
      );
    });

    test('a missing (absent, not just null) wordIds key is caught the same way', () {
      final data = validData()..remove('wordIds');

      expect(
        () => LearningSession.fromFirestore('test-session', data),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"wordIds"'),
          ),
        ),
      );
    });

    test('a present-but-wrong-type wordIds is still caught, with the document id', () {
      final data = validData()..['wordIds'] = 'run'; // string, not a list

      expect(
        () => LearningSession.fromFirestore('test-session', data),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('learningSessions/test-session'),
          ),
        ),
      );
    });

    test('other required fields (e.g. studentId) are also named when null', () {
      final data = validData()..['studentId'] = null;

      expect(
        () => LearningSession.fromFirestore('test-session', data),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"studentId"'),
          ),
        ),
      );
    });

    test('a valid document still parses normally (no false positives)', () {
      expect(
        () => LearningSession.fromFirestore('test-session', validData()),
        returnsNormally,
      );
    });
  });
}
