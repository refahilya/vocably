import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/learning_session.dart';
import 'firebase_service.dart';

/// Read/write access to `learningSessions` (`DATA_MODEL.md` §4). Reads
/// serve Riwayat's "Per Sesi" tab (Milestone 6); writes drive the Fase
/// 1–3 flow (Milestone 7) — `LearningSessionController` is the only
/// caller of the write methods below, per `CLAUDE.md` §4's "every
/// Firebase call goes through `services/`" rule.
///
/// **Deliberately a single-equality query with no `orderBy`,** unlike the
/// `studentId` + `orderBy(startedAt desc)` query `DATA_MODEL.md` §8
/// sketches — that combination needs a composite index (equality on one
/// field + `orderBy` on a different field), which isn't worth deploying
/// for this collection (see `PROJECT_STATE.md` §5i's fuller reasoning,
/// reaffirmed for Milestone 7: the project owner's Decision 1 explicitly
/// rules out adding any resume-related query/index). The provider layer
/// sorts the (small, per-student) result by `startedAt` descending in
/// memory instead — same reasoning as [LearningProgressService].
///
/// **No resume logic anywhere in this class** (project owner's Milestone
/// 7 Decision 1: every entry into the 3-phase flow always creates a new
/// `learningSessions` document; an abandoned/incomplete one is simply
/// left at its last persisted phase, with no special handling and no
/// query that looks for it).
class LearningSessionService {
  LearningSessionService([FirebaseService? firebaseService])
    : _firebaseService = firebaseService ?? const FirebaseService();

  final FirebaseService _firebaseService;

  CollectionReference<Map<String, dynamic>> get _learningSessions =>
      _firebaseService.firestore.collection('learningSessions');

  /// All sessions for [studentId], unsorted (the provider layer sorts by
  /// `startedAt` descending).
  Future<List<LearningSession>> fetchForStudent(String studentId) async {
    final snapshot = await _learningSessions.where('studentId', isEqualTo: studentId).get();

    return [
      for (final doc in snapshot.docs)
        LearningSession.fromFirestore(doc.id, doc.data()),
    ];
  }

  /// Creates a brand-new session document — Fase 1's **first** successful
  /// `/generate-story` call for this flow (`DATA_MODEL.md` §4). Uses an
  /// auto-generated `docId` (the schema doesn't specify a deterministic
  /// one for this collection, unlike `learningProgress`'s
  /// `{studentId}_{wordId}`). Returns the new doc's id, which the caller
  /// (`LearningSessionController`) holds for every subsequent write in
  /// this same flow.
  Future<String> createSession({
    required String studentId,
    required List<String> wordIds,
    required String sourceType,
    required String storyTitle,
    required String storyContent,
    required String? storyTranslation,
  }) async {
    final docRef = await _learningSessions.add(
      LearningSession.newSessionData(
        studentId: studentId,
        wordIds: wordIds,
        sourceType: sourceType,
        storyTitle: storyTitle,
        storyContent: storyContent,
        storyTranslation: storyTranslation,
      ),
    );
    return docRef.id;
  }

  /// Overwrites the story fields of an existing session that's still in
  /// [LearningSessionPhase.membaca] — a Fase 1 "Generate ulang"
  /// (`DATA_MODEL.md` §4: "ditimpa langsung"). Callers are responsible for
  /// only calling this while still in that phase; `firestore.rules`
  /// enforces the same constraint server-side.
  Future<void> overwriteStory({
    required String sessionId,
    required String storyTitle,
    required String storyContent,
    required String? storyTranslation,
  }) {
    return _learningSessions.doc(sessionId).update(
      LearningSession.storyUpdateData(
        storyTitle: storyTitle,
        storyContent: storyContent,
        storyTranslation: storyTranslation,
      ),
    );
  }

  /// Fase 1 → Fase 2: "Selanjutnya" locks the currently-displayed story as
  /// final simply by moving `currentPhase` forward — the story fields
  /// themselves are already correct from the last [overwriteStory]/
  /// [createSession] call, so this never touches them (`DATA_MODEL.md`
  /// §4: "field cerita hanya boleh ditimpa selama `currentPhase =
  /// membaca`... nilai `storyContent` pada saat transisi otomatis adalah
  /// cerita yang dipilih siswa").
  Future<void> advanceToClozeTest(String sessionId) {
    return _learningSessions.doc(sessionId).update({
      'currentPhase': LearningSessionPhase.clozeTest,
    });
  }

  /// Fase 2 → Fase 3: writes the final `clozeTestResult` (the whole map at
  /// once — never a partial field-path update, since target words can
  /// contain spaces, `DATA_MODEL.md` §4's explicit warning) and advances
  /// the phase in the same call.
  Future<void> recordClozeResult({
    required String sessionId,
    required Map<String, bool> clozeTestResult,
  }) {
    return _learningSessions.doc(sessionId).update({
      'clozeTestResult': clozeTestResult,
      'currentPhase': LearningSessionPhase.coWrite,
    });
  }

  /// Persists the co-write transcript so far — called after **every**
  /// turn, not only once at the end, so an abandoned mid-co-write session
  /// (project owner's Decision 1: "remains stored at its last persisted
  /// phase/state") actually has a meaningful last-persisted state rather
  /// than losing the whole phase. Always writes the complete transcript
  /// array (never a partial append) — the simplest way to stay correct
  /// without relying on Firestore array-union ordering semantics for a
  /// list this small.
  Future<void> saveCowriteTranscript({
    required String sessionId,
    required List<CowriteTurn> transcript,
  }) {
    return _learningSessions.doc(sessionId).update({
      'cowriteTranscript': [for (final turn in transcript) turn.toMap()],
    });
  }

  /// Fase 3 → `selesai`: the session's final write. `completedAt` uses
  /// `FieldValue.serverTimestamp()`, the same sentinel pattern used
  /// throughout this codebase for server-authoritative timestamps.
  Future<void> completeSession({
    required String sessionId,
    required List<CowriteTurn> transcript,
    required List<String> cowriteWordsUsedCorrectly,
  }) {
    return _learningSessions.doc(sessionId).update({
      'cowriteTranscript': [for (final turn in transcript) turn.toMap()],
      'cowriteWordsUsedCorrectly': cowriteWordsUsedCorrectly,
      'currentPhase': LearningSessionPhase.selesai,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }
}
