import 'package:cloud_firestore/cloud_firestore.dart';

/// `learningProgress.learnedStatus` values (`DATA_MODEL.md` §3).
abstract final class LearnedStatus {
  static const String belumDipelajari = 'belumDipelajari';
  static const String sudahDipelajari = 'sudahDipelajari';
}

/// `learningProgress.masteryStatus` values (`DATA_MODEL.md` §3). Only
/// meaningful when `learnedStatus == LearnedStatus.sudahDipelajari` — see
/// [LearningProgress.masteryStatus]'s own doc comment.
abstract final class MasteryStatus {
  static const String mastered = 'mastered';
  static const String difficult = 'difficult';
}

/// A `learningProgress/{studentId}_{wordId}` document (`DATA_MODEL.md`
/// §3) — one student's progress on one word.
///
/// Milestone 6 only *reads* this collection, for Riwayat's "Per Kata" tab.
/// Nothing writes it yet — that's Milestone 7 (the 3-phase flow is what
/// actually produces `sudahDipelajari`/mastery transitions), so in
/// practice every query against this collection returns an empty list
/// until then. This model exists now so Milestone 7 has a ready-made,
/// already-tested shape to write against rather than inventing one under
/// deadline pressure later.
class LearningProgress {
  const LearningProgress({
    required this.studentId,
    required this.wordId,
    required this.learnedStatus,
    required this.masteryStatus,
    required this.firstLearnedAt,
    required this.lastUpdatedAt,
    required this.lastSessionId,
  });

  final String studentId;

  /// Already-normalized — same string as the `vocabWords` docId.
  final String wordId;

  /// One of [LearnedStatus].
  final String learnedStatus;

  /// One of [MasteryStatus], or `null`. **Must be `null` whenever
  /// [learnedStatus] is [LearnedStatus.belumDipelajari]**, and non-null
  /// whenever it's [LearnedStatus.sudahDipelajari] — `DATA_MODEL.md` §3's
  /// "default `difficult`" rule (enforced by the writer, Milestone 7 — not
  /// this read-only model).
  final String? masteryStatus;

  final DateTime? firstLearnedAt;
  final DateTime lastUpdatedAt;
  final String lastSessionId;

  factory LearningProgress.fromFirestore(Map<String, dynamic> data) {
    final firstLearnedAtRaw = data['firstLearnedAt'];
    return LearningProgress(
      studentId: data['studentId'] as String,
      wordId: data['wordId'] as String,
      learnedStatus: data['learnedStatus'] as String,
      masteryStatus: data['masteryStatus'] as String?,
      firstLearnedAt: firstLearnedAtRaw is Timestamp
          ? firstLearnedAtRaw.toDate()
          : null,
      lastUpdatedAt: (data['lastUpdatedAt'] as Timestamp).toDate(),
      lastSessionId: data['lastSessionId'] as String,
    );
  }
}
