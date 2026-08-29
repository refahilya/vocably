import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/target_word_set.dart';
import '../utils/target_word_constants.dart';
import 'firebase_service.dart';

/// Read-only access to `targetWordSets` (`DATA_MODEL.md` §5) for the
/// student-facing "Target Kata Hari Ini" card. The guru-facing write path
/// ("Set Target Kata") is Milestone 8 — this service has no write methods.
class TargetWordSetService {
  TargetWordSetService([FirebaseService? firebaseService])
    : _firebaseService = firebaseService ?? const FirebaseService();

  final FirebaseService _firebaseService;

  CollectionReference<Map<String, dynamic>> get _targetWordSets =>
      _firebaseService.firestore.collection('targetWordSets');

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
