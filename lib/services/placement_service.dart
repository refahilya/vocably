import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/placement_attempt.dart';
import '../models/placement_instrument.dart';
import '../models/placement_status.dart';
import '../models/research_instrument.dart';
import '../models/research_participant.dart';
import '../models/research_study.dart';
import 'firebase_service.dart';
import 'research_assessment_service.dart';

/// Reads and writes the Placement Test collections for the signed-in
/// student (`DATA_MODEL.md` §6). Every write matches one branch of the
/// placement rules; every read used for a decision goes to the **server**,
/// so a pending or lost write is never mistaken for a saved one.
///
/// Failures are reported as [ResearchServiceException] (same mapping as the
/// pretest/posttest service). Writes are bounded by [timeout]; a timed-out
/// write may still land, so callers re-read before deciding anything.
class PlacementService {
  PlacementService({
    FirebaseService? firebaseService,
    AssetBundle? assetBundle,
    this.timeout = const Duration(seconds: 20),
  }) : _firebaseService = firebaseService ?? const FirebaseService(),
       _assetBundle = assetBundle ?? rootBundle;

  final FirebaseService _firebaseService;
  final AssetBundle _assetBundle;
  final Duration timeout;

  FirebaseFirestore get _db => _firebaseService.firestore;
  static const _fromServer = GetOptions(source: Source.server);

  DocumentReference<Map<String, dynamic>> _attemptRef(String id) =>
      _db.collection('placementAttempts').doc(id);

  /// The bundled app-safe bank (items and options only — no key).
  Future<PlacementInstrument> loadInstrument() async {
    String raw;
    try {
      raw = await _assetBundle.loadString(kPlacementBankAsset);
    } catch (_) {
      throw const PlacementInstrumentException('placement bank asset could not be loaded');
    }
    try {
      return PlacementInstrument.fromJson(jsonDecode(raw));
    } on FormatException {
      throw const PlacementInstrumentException('placement bank asset is not valid JSON');
    }
  }

  /// `null` when the researcher has not configured the Placement Test.
  Future<PlacementConfig?> fetchConfig() => _guard(() async {
    final data = (await _db.collection('placementConfig').doc('current').get(_fromServer)).data();
    if (data == null) return null;
    final version = data['instrumentVersion'];
    if (version is! String) {
      throw const PlacementInstrumentException('placement config is invalid');
    }
    return PlacementConfig(instrumentVersion: version, learningOpen: data['learningOpen'] == true);
  });

  Future<ResearchStudy> fetchStudy() => _guard(() async {
    final snapshot = await _db.collection('researchStudy').doc('current').get(_fromServer);
    return ResearchStudy.fromFirestore(snapshot.data());
  });

  Future<ResearchParticipant?> fetchParticipant(String uid) => _guard(() async {
    final data = (await _db.collection('researchParticipants').doc(uid).get(_fromServer)).data();
    return data == null ? null : ResearchParticipant.fromFirestore(data);
  });

  /// All of the student's own attempts (rules allow only this query shape).
  Future<List<PlacementAttemptRecord>> fetchOwnAttempts(String uid) => _guard(() async {
    final snapshot = await _db
        .collection('placementAttempts')
        .where('studentId', isEqualTo: uid)
        .get(_fromServer);
    return [
      for (final doc in snapshot.docs) PlacementAttemptRecord.fromFirestore(doc.id, doc.data()),
    ];
  });

  Future<PlacementAttemptRecord?> fetchAttempt(String id) => _guard(() async {
    final data = (await _attemptRef(id).get(_fromServer)).data();
    return data == null ? null : PlacementAttemptRecord.fromFirestore(id, data);
  });

  /// `set` on a missing document is a create; an existing attempt is never
  /// overwritten (the rules evaluate it as an update and refuse it).
  Future<void> createAttempt({
    required String studentId,
    required PlacementContext context,
    required int attemptNumber,
    required List<String> itemOrder,
  }) => _guard(
    () => _attemptRef(PlacementAttemptRecord.idFor(studentId, context, attemptNumber)).set(
      PlacementAttemptRecord.newAttemptData(
        studentId: studentId,
        context: context,
        attemptNumber: attemptNumber,
        itemOrder: itemOrder,
        serverTimestamp: FieldValue.serverTimestamp(),
      ),
    ),
  );

  /// Saves (or changes) one answer; idempotent, so a retry is safe.
  Future<void> saveAnswer({
    required String attemptId,
    required String itemId,
    required String answer,
  }) => _guard(
    () => _attemptRef(attemptId).update(
      PlacementAttemptRecord.answerUpdateData(
        itemId: itemId,
        answer: answer,
        serverTimestamp: FieldValue.serverTimestamp(),
      ),
    ),
  );

  /// Records one "app hidden" signal. Recorded only; nothing acts on it.
  Future<void> recordHidden(String attemptId, int newCount) => _guard(
    () => _attemptRef(attemptId).update(
      PlacementAttemptRecord.tabSwitchData(newCount, FieldValue.serverTimestamp()),
    ),
  );

  /// Freezes the answers; the rules refuse it unless all 50 are saved and
  /// the stage (research) or learning placement is open.
  Future<void> submit(String attemptId) => _guard(
    () => _attemptRef(attemptId).update(PlacementAttemptRecord.submitData(FieldValue.serverTimestamp())),
  );

  /// Scores a submitted attempt: proposes each possible result in one batch
  /// (attempt + `users` level + — research — the participant band). The
  /// rules recompute the K2 decision from the frozen answers and the key
  /// and accept only the exact result, so at most one batch commits.
  /// Returns the accepted result, or `null` when every proposal was refused
  /// (already scored, voided, or blocked by a pending review — re-read).
  Future<PlacementResult?> score(PlacementAttemptRecord attempt) async {
    for (final candidate in PlacementResult.candidates) {
      try {
        await _guard(() {
          final batch = _db.batch();
          final now = FieldValue.serverTimestamp();
          batch.update(_attemptRef(attempt.id), PlacementAttemptRecord.scoreData(candidate, now));
          batch.update(
            _db.collection('users').doc(attempt.studentId),
            PlacementAttemptRecord.userResultData(candidate, attempt.id),
          );
          if (attempt.context == PlacementContext.research) {
            batch.update(
              _db.collection('researchParticipants').doc(attempt.studentId),
              PlacementAttemptRecord.participantBandData(candidate, attempt.id, now),
            );
          }
          return batch.commit();
        });
        return candidate;
      } on ResearchServiceException catch (error) {
        if (error.kind != ResearchFailureKind.permissionDenied) rethrow;
      }
    }
    return null;
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
    } on PlacementInstrumentException catch (error) {
      throw ResearchServiceException(ResearchFailureKind.invalidData, error.message);
    } on ResearchInstrumentException catch (error) {
      throw ResearchServiceException(ResearchFailureKind.invalidData, error.message);
    }
  }
}
