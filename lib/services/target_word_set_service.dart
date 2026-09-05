import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/target_word_set.dart';
import '../utils/target_word_constants.dart';
import 'firebase_service.dart';

/// Read/write access to `targetWordSets` (`DATA_MODEL.md` §5). Reads
/// serve the student-facing "Target Kata Hari Ini" card (Milestone 6) and
/// the guru-facing target list (Milestone 8); writes serve the guru
/// "Set Target Kata" flow (Milestone 8).
class TargetWordSetService {
  TargetWordSetService([FirebaseService? firebaseService])
    : _firebaseService = firebaseService ?? const FirebaseService();

  final FirebaseService _firebaseService;

  CollectionReference<Map<String, dynamic>> get _targetWordSets =>
      _firebaseService.firestore.collection('targetWordSets');

  /// Creates a brand-new `targetWordSets` document authored by [teacherId]
  /// (`DATA_MODEL.md` §5). Uses an auto-generated docId (`.add()`).
  Future<String> createTargetWordSet({
    required String teacherId,
    required List<String> wordIds,
    required String cefrLevel,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final docRef = await _targetWordSets.add(
      TargetWordSet.newTargetWordSetData(
        teacherId: teacherId,
        wordIds: wordIds,
        cefrLevel: cefrLevel,
        startAt: startAt,
        endAt: endAt,
      ),
    );
    return docRef.id;
  }

  /// All target word sets created by [teacherId], unsorted (the provider
  /// layer sorts in memory). Uses single-field equality on `teacherId` to
  /// avoid requiring an additional composite index.
  Future<List<TargetWordSet>> fetchForTeacher(String teacherId) async {
    final snapshot = await _targetWordSets
        .where('teacherId', isEqualTo: teacherId)
        .get();

    return [
      for (final doc in snapshot.docs)
        TargetWordSet.fromFirestore(doc.id, doc.data()),
    ];
  }

  /// The target word sets currently active for [studentId] — i.e.
  /// targeted at either [studentId] specifically or [kAllStudents], not
  /// yet past `endAt`, and already past `startAt`.
  ///
  /// Runs the exact query `DATA_MODEL.md` §5 documents (array-contains-any
  /// on [targetStudentIds] + a range/order on `endAt`, needing the
  /// composite index in `firestore.indexes.json`), then filters `startAt`
  /// client-side — the doc's own stated reason: "sisa filter di client
  /// murah karena hasil query-nya kecil".
  Future<List<TargetWordSet>> fetchActiveForStudent(String studentId) async {
    final now = DateTime.now();
    final snapshot = await _targetWordSets
        .where('targetStudentIds', arrayContainsAny: [kAllStudents, studentId])
        .where('endAt', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('endAt')
        .get();

    final sets = [
      for (final doc in snapshot.docs)
        TargetWordSet.fromFirestore(doc.id, doc.data()),
    ];

    return filterStillActive(sets, now);
  }
}

/// The client-side half of `DATA_MODEL.md` §5's query — sets whose
/// `endAt` already passed the server-side filter above, narrowed to only
/// those whose `startAt` has actually arrived. Factored out as a pure
/// function (no Firestore dependency) so it's independently testable,
/// mirroring `mergeBundleWithDelta`'s split out of `VocabBundleService`.
List<TargetWordSet> filterStillActive(List<TargetWordSet> sets, DateTime now) {
  return [
    for (final set in sets)
      if (!set.startAt.isAfter(now)) set,
  ];
}
