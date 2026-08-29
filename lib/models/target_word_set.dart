import 'package:cloud_firestore/cloud_firestore.dart';

/// A `targetWordSets/{docId}` document (`DATA_MODEL.md` §5) — a batch of
/// words a guru targeted for students over some time range.
///
/// Milestone 6 only *reads* this collection (dashboard "Target Kata Hari
/// Ini") — the guru-facing write path ("Set Target Kata") is Milestone 8.
/// `endAt`/`targetStudentIds` are never `null` in a well-formed document
/// (see `utils/target_word_constants.dart`), but this model doesn't assert
/// that on the way in — a malformed document should fail to parse loudly
/// (same posture as [VocabWord.fromFirestore]), not be silently coerced.
class TargetWordSet {
  const TargetWordSet({
    required this.id,
    required this.teacherId,
    required this.wordIds,
    required this.cefrLevel,
    required this.startAt,
    required this.endAt,
    required this.targetStudentIds,
    required this.createdAt,
  });

  /// Firestore `docId` — not itself a schema field, kept for convenience
  /// (e.g. as a Riverpod/list key), same convention as would apply to any
  /// other model that doesn't embed its own id in the document body.
  final String id;

  final String teacherId;

  /// Already-normalized words (`DATA_MODEL.md` §5) — same string shape as
  /// `vocabWords` docIds.
  final List<String> wordIds;

  final String cefrLevel;
  final DateTime startAt;

  /// Never a "real" `null` in a well-formed document — see
  /// `kNoEndDate` in `utils/target_word_constants.dart`.
  final DateTime endAt;

  /// Never empty in a well-formed document — `[kAllStudents]` stands in
  /// for "every student" (`utils/target_word_constants.dart`).
  final List<String> targetStudentIds;

  final DateTime createdAt;

  factory TargetWordSet.fromFirestore(String id, Map<String, dynamic> data) {
    return TargetWordSet(
      id: id,
      teacherId: data['teacherId'] as String,
      wordIds: [for (final w in data['wordIds'] as List) w as String],
      cefrLevel: data['cefrLevel'] as String,
      startAt: (data['startAt'] as Timestamp).toDate(),
      endAt: (data['endAt'] as Timestamp).toDate(),
      targetStudentIds: [
        for (final s in data['targetStudentIds'] as List) s as String,
      ],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
