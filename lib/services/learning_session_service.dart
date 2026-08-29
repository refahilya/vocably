import '../models/learning_session.dart';
import 'firebase_service.dart';

/// Read-only access to `learningSessions` (`DATA_MODEL.md` §4) for
/// Riwayat's "Per Sesi" tab. Nothing writes this collection yet — that's
/// Milestone 7 — so this service has no write methods.
///
/// **Deliberately a single-equality query with no `orderBy`,** unlike the
/// `studentId` + `orderBy(startedAt desc)` query `DATA_MODEL.md` §8
/// sketches — that combination needs a composite index (equality on one
/// field + `orderBy` on a different field), which isn't worth deploying
/// for a collection nothing writes to before Milestone 7. The provider
/// layer sorts the (small, per-student) result by `startedAt` descending
/// in memory instead — same reasoning as [LearningProgressService].
class LearningSessionService {
  LearningSessionService([FirebaseService? firebaseService])
    : _firebaseService = firebaseService ?? const FirebaseService();

  final FirebaseService _firebaseService;

  /// All sessions for [studentId], unsorted (the provider layer sorts by
  /// `startedAt` descending). Empty in practice until Milestone 7 starts
  /// writing this collection.
  Future<List<LearningSession>> fetchForStudent(String studentId) async {
    final snapshot = await _firebaseService.firestore
        .collection('learningSessions')
        .where('studentId', isEqualTo: studentId)
        .get();

    return [
      for (final doc in snapshot.docs)
        LearningSession.fromFirestore(doc.id, doc.data()),
    ];
  }
}
