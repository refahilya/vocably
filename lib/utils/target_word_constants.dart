/// Sentinel values for `targetWordSets` (`DATA_MODEL.md` §5, `CLAUDE.md`
/// §4: "Jangan hardcode nilai sentinel. `kNoEndDate` dan `kAllStudents`
/// hidup sebagai konstanta di `utils/`, dipakai di semua tempat yang
/// menulis atau membaca `targetWordSets`").
///
/// `targetWordSets.endAt` and `targetWordSets.targetStudentIds` are never
/// `null` — a document written with `null` in either field silently drops
/// out of the query in `DATA_MODEL.md` §5, with no error anywhere. These
/// constants are the one place both values live.
///
/// Milestone 6 is the first code to actually read `targetWordSets`
/// (Milestone 8 is what writes it) — these constants are introduced now,
/// on the read side, and must be reused unchanged when Milestone 8 builds
/// the write path.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Stand-in for "no end date" — a `targetWordSets.endAt` that should never
/// expire. `DATA_MODEL.md` §5 gives `2099-12-31` as the example sentinel.
final Timestamp kNoEndDate = Timestamp.fromDate(DateTime.utc(2099, 12, 31));

/// Stand-in for "every student" in `targetWordSets.targetStudentIds`, used
/// instead of an empty/null array.
const String kAllStudents = '__all__';
