import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/research_panel.dart';
import 'firebase_service.dart';
import 'research_assessment_service.dart';

/// Reads and writes for the Researcher Panel (`DATA_MODEL.md` §6d), used
/// only by the single researcher operator. Identity comes from the ordinary
/// Firebase Auth sign-in; authority comes from `researchOperators/{uid}`,
/// which only the research tooling writes. Every action is one batch that
/// the security rules re-check in full, so the panel never needs to be
/// trusted: hiding a button is convenience, not protection.
///
/// The panel never reads attempt documents (they hold the answers); it
/// reads the `researchProgress` mirrors instead.
class ResearchPanelService {
  ResearchPanelService({
    FirebaseService? firebaseService,
    this.timeout = const Duration(seconds: 20),
  }) : _firebaseService = firebaseService ?? const FirebaseService();

  final FirebaseService _firebaseService;
  final Duration timeout;

  FirebaseFirestore get _db => _firebaseService.firestore;

  static const _fromServer = GetOptions(source: Source.server);

  /// `true` while [uid] holds an active operator record. A missing record,
  /// or a read the rules refuse, is `false`.
  Stream<bool> watchOperator(String uid) => _db
      .collection('researchOperators')
      .doc(uid)
      .snapshots()
      .map((s) => s.data()?['active'] == true)
      .transform(
        StreamTransformer<bool, bool>.fromHandlers(handleError: (_, _, sink) => sink.add(false)),
      );

  Stream<PanelStudy> watchStudy() => _db
      .collection('researchStudy')
      .doc('current')
      .snapshots()
      .map((s) => PanelStudy.fromFirestore(s.data()));

  Stream<List<PanelParticipant>> watchParticipants() => _db
      .collection('researchParticipants')
      .snapshots()
      .map((q) => [for (final d in q.docs) PanelParticipant.fromFirestore(d.id, d.data())]);

  Stream<List<PanelRosterEntry>> watchRoster() => _db
      .collection('researchRoster')
      .snapshots()
      .map((q) => [for (final d in q.docs) PanelRosterEntry.fromFirestore(d.id, d.data())]);

  Stream<List<PanelProgress>> watchProgress() => _db.collection('researchProgress').snapshots().map(
    (q) => [
      for (final d in q.docs) ?PanelProgress.fromFirestore(d.id, d.data()),
    ],
  );

  Stream<List<PanelAuditEntry>> watchAudit({int limit = 12}) => _db
      .collection('researchAuditLog')
      .orderBy('at', descending: true)
      .limit(limit)
      .snapshots()
      .map((q) => [for (final d in q.docs) PanelAuditEntry.fromFirestore(d.id, d.data())]);

  /// The current window-change sequence number, from the server (the rules
  /// require exactly the next one).
  Future<int> _currentSeq() async {
    final snapshot = await _db.collection('researchStudy').doc('current').get(_fromServer);
    return PanelStudy.fromFirestore(snapshot.data()).operatorSeq;
  }

  Future<void> openStage({required String operatorUid, required PanelStage stage, Duration? duration}) => _guard(() async {
    final seq = await _currentSeq() + 1;
    await _commit(
      ResearchPanelWrites.openStage(
        stage: stage,
        seq: seq,
        operatorUid: operatorUid,
        serverTimestamp: FieldValue.serverTimestamp(),
        closeAt: duration == null ? null : DateTime.now().add(duration),
      ),
    );
  });

  Future<void> closeStage({required String operatorUid, required PanelStage stage}) => _guard(() async {
    final seq = await _currentSeq() + 1;
    await _commit(
      ResearchPanelWrites.closeStage(
        stage: stage,
        seq: seq,
        operatorUid: operatorUid,
        serverTimestamp: FieldValue.serverTimestamp(),
      ),
    );
  });

  Future<void> authorize({required String operatorUid, required PanelRow row, required PanelStage stage}) => _guard(
    () => _commit(
      ResearchPanelWrites.authorize(
        uid: row.uid,
        stage: stage,
        bandFromPlacement: row.participant.bandFromPlacement,
        operatorUid: operatorUid,
        serverTimestamp: FieldValue.serverTimestamp(),
      ),
    ),
  );

  Future<void> retake({
    required String operatorUid,
    required PanelRow row,
    required PanelStage stage,
    required bool voidCurrent,
  }) => _guard(
    () => _commit(
      ResearchPanelWrites.retake(
        uid: row.uid,
        stage: stage,
        n: row.participant.attempt(stage),
        voidCurrent: voidCurrent,
        operatorUid: operatorUid,
        serverTimestamp: FieldValue.serverTimestamp(),
      ),
    ),
  );

  Future<void> _commit(List<PanelWrite> writes) {
    final batch = _db.batch();
    for (final w in writes) {
      final ref = _db.doc(w.path);
      if (w.isSet) {
        batch.set(ref, w.data);
      } else {
        batch.update(ref, w.data);
      }
    }
    return batch.commit();
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(timeout);
    } on TimeoutException {
      throw const ResearchServiceException(ResearchFailureKind.timeout, 'no response from the server in time');
    } on FirebaseException catch (error) {
      throw ResearchServiceException(switch (error.code) {
        'permission-denied' => ResearchFailureKind.permissionDenied,
        'unavailable' || 'deadline-exceeded' => ResearchFailureKind.unavailable,
        _ => ResearchFailureKind.unknown,
      }, error.code);
    }
  }
}
