import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/learning_session.dart';
import '../models/research_treatment.dart';
import '../models/target_word_set.dart';
import 'firebase_service.dart';

/// Completed official sessions in [sessions] whose number is not in [done]:
/// the earliest completed one per session number, in completion order.
List<LearningSession> unrecordedCompleted(List<LearningSession> sessions, Set<int> done) {
  final completed = sessions
      .where((s) => s.isResearchSession && s.targetWordSetId != null && s.currentPhase == LearningSessionPhase.selesai)
      .toList()
    ..sort((a, b) => (a.completedAt ?? a.startedAt).compareTo(b.completedAt ?? b.startedAt));
  final seen = {...done};
  return [
    for (final s in completed)
      if (seen.add(s.researchSession!)) s,
  ];
}

/// The student side of the research treatment (`DATA_MODEL.md` §6e): reads
/// the student's own completion record and writes one completion per
/// official session. The rules accept a completion only when the learning
/// session it names is that official session, completed with full
/// evidence — this service never decides anything the rules don't re-check.
class ResearchTreatmentService {
  ResearchTreatmentService([FirebaseService? firebaseService, this.timeout = const Duration(seconds: 20)])
    : _firebaseService = firebaseService ?? const FirebaseService();

  final FirebaseService _firebaseService;
  final Duration timeout;

  FirebaseFirestore get _db => _firebaseService.firestore;

  static const _fromServer = GetOptions(source: Source.server);

  DocumentReference<Map<String, dynamic>> _record(String uid) => _db.collection('researchTreatment').doc(uid);

  /// Whether [uid] has a research participant record (only participants
  /// have official sessions).
  Future<bool> isParticipant(String uid) async =>
      (await _db.collection('researchParticipants').doc(uid).get(_fromServer).timeout(timeout)).exists;

  /// The student's own completion record; empty when none exists yet.
  Future<TreatmentRecord> fetchRecord(String uid) async {
    final snapshot = await _record(uid).get(_fromServer).timeout(timeout);
    return TreatmentRecord.fromFirestore(uid, snapshot.data());
  }

  Future<TargetWordSet?> fetchSet(String setId) async {
    final snapshot = await _db.collection('targetWordSets').doc(setId).get().timeout(timeout);
    final data = snapshot.data();
    return data == null ? null : TargetWordSet.fromFirestore(snapshot.id, data);
  }

  /// Records official session [ref] as completed by learning session
  /// [sessionId]. A session already recorded is left as it is.
  Future<void> recordCompletion({required String uid, required ResearchSessionRef ref, required String sessionId}) async {
    final existing = await _record(uid).get(_fromServer).timeout(timeout);
    final record = TreatmentRecord.fromFirestore(uid, existing.data());
    if (record.done.contains(ref.session)) return;
    final write = ResearchTreatmentWrites.recordCompletion(
      uid: uid,
      exists: existing.exists,
      ref: ref,
      sessionId: sessionId,
      serverTimestamp: FieldValue.serverTimestamp(),
    );
    final doc = _db.doc(write.path);
    await (write.isSet ? doc.set(write.data) : doc.update(write.data)).timeout(timeout);
  }

  /// Writes any completion the app could not record when the session ended
  /// (e.g. the connection dropped): completed official sessions in
  /// [sessions] whose number is not recorded yet, earliest first. Returns
  /// how many were recorded.
  Future<int> reconcile({required String uid, required List<LearningSession> sessions}) async {
    if (unrecordedCompleted(sessions, const {}).isEmpty) return 0;
    final done = (await fetchRecord(uid)).done;
    var written = 0;
    for (final s in unrecordedCompleted(sessions, done)) {
      final set = await fetchSet(s.targetWordSetId!);
      final info = set?.research;
      if (info == null || info.session != s.researchSession) continue;
      await recordCompletion(
        uid: uid,
        ref: ResearchSessionRef(setId: set!.id, session: info.session, kind: info.kind, planVersion: info.planVersion),
        sessionId: s.id,
      );
      done.add(info.session);
      written++;
    }
    return written;
  }
}
