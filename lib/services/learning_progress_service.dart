import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/learning_progress.dart';
import '../utils/mastery_rules.dart';
import 'firebase_service.dart';

/// Read/write access to `learningProgress` (`DATA_MODEL.md` §3). Reads
/// serve Riwayat's "Per Kata" tab (Milestone 6); writes implement the
/// mastery state machine (`DATA_MODEL.md` §3, `SPEC.md` §6) in two steps,
/// per the project owner's Milestone 7 Decision 3 — see
/// [recordClozeCompletion]/[recordCowriteCompletion] and
/// `utils/mastery_rules.dart`'s own doc comment for the full two-write
/// rationale.
///
/// **Deliberately a single-equality query with no `orderBy`,** unlike the
/// two-field query `DATA_MODEL.md` §8 sketches (`studentId` +
/// `masteryStatus`, for "sort/filter by label"). A student's own progress
/// rows are a small, per-student list (bounded by how many words exist at
/// all, not by traffic), so filtering/sorting by mastery label is done in
/// the provider layer instead — the same in-memory-filter convention
/// `utils/vocab_browse_filter.dart` already established for a much larger
/// list. This keeps the query to Firestore's automatic single-field
/// index, with no composite index to deploy.
class LearningProgressService {
  LearningProgressService([FirebaseService? firebaseService])
    : _firebaseService = firebaseService ?? const FirebaseService();

  final FirebaseService _firebaseService;

  CollectionReference<Map<String, dynamic>> get _learningProgress =>
      _firebaseService.firestore.collection('learningProgress');

  /// All progress rows for [studentId], unsorted (the provider layer sorts/
  /// filters).
  Future<List<LearningProgress>> fetchForStudent(String studentId) async {
    final snapshot = await _learningProgress.where('studentId', isEqualTo: studentId).get();

    return [
      for (final doc in snapshot.docs) LearningProgress.fromFirestore(doc.data()),
    ];
  }

  /// **Step 1 of 2** of the mastery write (Fase 2 → Fase 3 transition,
  /// called right after `LearningSessionService.recordClozeResult`): for
  /// every word in [wordIds], makes sure a `learningProgress` doc exists
  /// with `learnedStatus: sudahDipelajari` — creating it with the default
  /// `difficult` mastery (`utils/mastery_rules.dart`'s
  /// `initialMasteryStatus()`) the first time this word is ever learned,
  /// or just refreshing `lastUpdatedAt`/`lastSessionId` (never
  /// `masteryStatus`) if it already existed.
  ///
  /// Runs one Firestore transaction per word — not a single transaction
  /// across every word — so a doc that already exists for one word in the
  /// list can't block/retry unnecessarily against contention on another,
  /// unrelated word's doc. Each individual word's read-then-write is still
  /// atomic, which is what actually matters for correctness here (per the
  /// project owner's Decision 3: "use a Firestore transaction... to
  /// preserve the no-downgrade rule under concurrent writes").
  Future<void> recordClozeCompletion({
    required String studentId,
    required List<String> wordIds,
    required String sessionId,
  }) async {
    for (final wordId in wordIds) {
      final docRef = _learningProgress.doc(
        LearningProgress.docId(studentId: studentId, wordId: wordId),
      );
      await _firebaseService.firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          transaction.set(
            docRef,
            LearningProgress.newLearnedData(
              studentId: studentId,
              wordId: wordId,
              masteryStatus: initialMasteryStatus(),
              lastSessionId: sessionId,
            ),
          );
        } else {
          transaction.update(
            docRef,
            LearningProgress.touchData(lastSessionId: sessionId),
          );
        }
      });
    }
  }

  /// **Step 2 of 2** of the mastery write (Fase 3 completion, called right
  /// before/alongside `LearningSessionService.completeSession`): for
  /// every word in [clozeTestResult]'s keys, upgrades `masteryStatus` to
  /// `mastered` if it was correct in the cloze test **and** used
  /// independently in co-write (`cowriteWordsUsedCorrectly`) — per
  /// `utils/mastery_rules.dart`'s `upgradedMasteryStatus()`, which also
  /// guarantees an already-`mastered` word is never touched.
  ///
  /// Every word passed in is expected to already have a doc from
  /// [recordClozeCompletion] earlier in the same flow — this method
  /// doesn't create new docs, only updates existing ones.
  Future<void> recordCowriteCompletion({
    required String studentId,
    required Map<String, bool> clozeTestResult,
    required List<String> cowriteWordsUsedCorrectly,
    required String sessionId,
  }) async {
    for (final entry in clozeTestResult.entries) {
      final wordId = entry.key;
      final correctInCloze = entry.value;
      final docRef = _learningProgress.doc(
        LearningProgress.docId(studentId: studentId, wordId: wordId),
      );

      await _firebaseService.firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final data = snapshot.data();
        if (data == null) {
          // Defensive only — recordClozeCompletion always runs first in
          // the real flow, so this doc should always already exist.
          return;
        }
        final current = LearningProgress.fromFirestore(data);
        final newMastery = upgradedMasteryStatus(
          currentMasteryStatus: current.masteryStatus ?? initialMasteryStatus(),
          correctInCloze: correctInCloze,
          usedIndependentlyInCowrite: cowriteWordsUsedCorrectly.contains(wordId),
        );
        transaction.update(
          docRef,
          LearningProgress.touchData(
            lastSessionId: sessionId,
            masteryStatus: newMastery,
          ),
        );
      });
    }
  }
}
