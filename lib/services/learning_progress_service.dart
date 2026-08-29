import '../models/learning_progress.dart';
import 'firebase_service.dart';

/// Read-only access to `learningProgress` (`DATA_MODEL.md` §3) for
/// Riwayat's "Per Kata" tab. Nothing writes this collection yet — that's
/// Milestone 7 — so this service has no write methods.
///
/// **Deliberately a single-equality query with no `orderBy`,** unlike the
/// two-field query `DATA_MODEL.md` §8 sketches (`studentId` +
/// `masteryStatus`, for "sort/filter by label"). A student's own progress
/// rows are a small, per-student list (bounded by how many words exist at
/// all, not by traffic), so filtering/sorting by mastery label is done in
/// the provider layer instead — the same in-memory-filter convention
/// `utils/vocab_browse_filter.dart` already established for a much larger
/// list. This keeps the query to Firestore's automatic single-field
/// index, with no composite index to deploy for a collection nothing
/// writes to yet.
class LearningProgressService {
  LearningProgressService([FirebaseService? firebaseService])
    : _firebaseService = firebaseService ?? const FirebaseService();

  final FirebaseService _firebaseService;

  /// All progress rows for [studentId], unsorted (the provider layer sorts/
  /// filters). Empty in practice until Milestone 7 starts writing this
  /// collection.
  Future<List<LearningProgress>> fetchForStudent(String studentId) async {
    final snapshot = await _firebaseService.firestore
        .collection('learningProgress')
        .where('studentId', isEqualTo: studentId)
        .get();

    return [
      for (final doc in snapshot.docs) LearningProgress.fromFirestore(doc.data()),
    ];
  }
}
