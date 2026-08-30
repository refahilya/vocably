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

  /// `docId` for the `learningProgress/{studentId}_{wordId}` document
  /// (`DATA_MODEL.md` §3) — the one and only place this format is
  /// computed, so every writer/reader agrees on it.
  static String docId({required String studentId, required String wordId}) =>
      '${studentId}_$wordId';

  /// The write map for a **brand-new** progress doc — a word's very first
  /// time being learned (`DATA_MODEL.md` §3 rule 1: default
  /// `masteryStatus: difficult`, `learnedStatus: sudahDipelajari`
  /// immediately, no in-between state). [masteryStatus] is passed in
  /// (rather than hardcoded) so the single source of truth for "what does
  /// a first-time learn default to" stays `utils/mastery_rules.dart`'s
  /// `initialMasteryStatus()`, not duplicated here.
  static Map<String, dynamic> newLearnedData({
    required String studentId,
    required String wordId,
    required String masteryStatus,
    required String lastSessionId,
  }) {
    return {
      'studentId': studentId,
      'wordId': wordId,
      'learnedStatus': LearnedStatus.sudahDipelajari,
      'masteryStatus': masteryStatus,
      'firstLearnedAt': FieldValue.serverTimestamp(),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'lastSessionId': lastSessionId,
    };
  }

  /// The write map for touching an **existing** progress doc again —
  /// either just bookkeeping (`lastUpdatedAt`/`lastSessionId` refreshed,
  /// `masteryStatus` unchanged) or an actual mastery upgrade
  /// (`masteryStatus` included). `learnedStatus`/`firstLearnedAt` are
  /// never part of this map — once a word is learned, those two fields
  /// never change again.
  static Map<String, dynamic> touchData({
    required String lastSessionId,
    String? masteryStatus,
  }) {
    return {
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'lastSessionId': lastSessionId,
      'masteryStatus': ?masteryStatus,
    };
  }
}
