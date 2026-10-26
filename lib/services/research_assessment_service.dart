import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/research_attempt.dart';
import '../models/research_attempt_plan.dart';
import '../models/research_instrument.dart';
import '../models/research_participant.dart';
import 'firebase_service.dart';

/// Why a research read or write failed, reduced to what the app acts on.
enum ResearchFailureKind {
  /// The research rules refused the operation (not authorized any more,
  /// attempt superseded/voided/completed, answer already saved, bank data
  /// not seeded, …).
  permissionDenied,

  /// No connection, or the server could not be reached.
  unavailable,

  /// No answer within the time limit. The write may still reach the server
  /// later; callers must re-read before deciding anything.
  timeout,

  /// Stored data doesn't match the research data model.
  invalidData,

  unknown,
}

class ResearchServiceException implements Exception {
  const ResearchServiceException(this.kind, this.message);

  final ResearchFailureKind kind;
  final String message;

  @override
  String toString() => 'ResearchServiceException(${kind.name}): $message';
}

/// What the app may currently do for one stage, derived from the server's
/// view of the participant record and the currently authorized attempt.
enum ResearchStageKind {
  /// No `researchParticipants/{uid}` record: not a study participant.
  notEnrolled,

  /// Enrolled, but this stage's attempt is not authorized (`0`).
  notAuthorized,

  /// Posttest authorized, but the authorized pretest attempt is not
  /// completed (the rules refuse a posttest until it is).
  locked,

  /// Authorized, attempt not created yet.
  notStarted,
  inProgress,
  completed,

  /// The authorized attempt was voided by the researcher and no retake has
  /// been authorized yet.
  voided,

  /// The stored attempt contradicts the participant record (band, version,
  /// owner or number).
  invalid,
}

class ResearchStageSnapshot {
  const ResearchStageSnapshot({
    required this.kind,
    this.participant,
    this.attemptId,
    this.attempt,
  });

  final ResearchStageKind kind;
  final ResearchParticipant? participant;

  /// `{uid}_{stage}_{n}` for the authorized attempt number, when there is one.
  final String? attemptId;
  final ResearchAttemptRecord? attempt;
}

/// Reads and writes the research collections for the signed-in student
/// (`DATA_MODEL.md` §6b). Every write matches the research rules exactly;
/// every read used for a decision goes to the **server** (never the local
/// cache), so a pending or lost write is never mistaken for a saved one.
///
/// Writes are bounded by [timeout]. A timed-out write may still be applied
/// later, which is why callers always re-read the attempt afterwards
/// instead of trusting the outcome of the write call.
class ResearchAssessmentService {
  ResearchAssessmentService({
    FirebaseService? firebaseService,
    this.timeout = const Duration(seconds: 20),
  }) : _firebaseService = firebaseService ?? const FirebaseService();

  final FirebaseService _firebaseService;
  final Duration timeout;

  FirebaseFirestore get _db => _firebaseService.firestore;

  DocumentReference<Map<String, dynamic>> _attemptRef(String attemptId) =>
      _db.collection('researchAssessmentResults').doc(attemptId);

  static const _fromServer = GetOptions(source: Source.server);

  /// The student's own participant record, or `null` if not enrolled.
  Future<ResearchParticipant?> fetchParticipant(String uid) => _guard(() async {
    final snapshot = await _db
        .collection('researchParticipants')
        .doc(uid)
        .get(_fromServer);
    final data = snapshot.data();
    return data == null ? null : ResearchParticipant.fromFirestore(data);
  });

  /// The attempt [attemptId], or `null` if it hasn't been created.
  Future<ResearchAttemptRecord?> fetchAttempt(String attemptId) =>
      _guard(() async {
        final snapshot = await _attemptRef(attemptId).get(_fromServer);
        final data = snapshot.data();
        return data == null
            ? null
            : ResearchAttemptRecord.fromFirestore(attemptId, data);
      });

  /// Creates the attempt with [plan]'s order. `set` on a missing document
  /// is a create; if the document already exists the rules evaluate it as
  /// an update and refuse it, so an existing attempt is never overwritten.
  Future<void> createAttempt({
    required String studentId,
    required ResearchStage stage,
    required int attemptNumber,
    required ResearchAttemptPlan plan,
  }) => _guard(
    () =>
        _attemptRef(
          ResearchAttemptRecord.idFor(studentId, stage, attemptNumber),
        ).set(
          ResearchAttemptRecord.newAttemptData(
            studentId: studentId,
            stage: stage,
            attemptNumber: attemptNumber,
            plan: plan,
            serverTimestamp: FieldValue.serverTimestamp(),
          ),
        ),
  );

  /// Saves one answer. The rules refuse it if the item already has one.
  Future<void> saveAnswer({
    required String attemptId,
    required String itemId,
    required ResearchResponse response,
  }) => _guard(
    () => _attemptRef(attemptId).update(
      ResearchAttemptRecord.answerUpdateData(
        itemId: itemId,
        response: response,
        serverTimestamp: FieldValue.serverTimestamp(),
      ),
    ),
  );

  /// Marks the attempt completed. The rules refuse it unless all 20 items
  /// have a saved answer.
  Future<void> completeAttempt(String attemptId) => _guard(
    () => _attemptRef(attemptId).update(
      ResearchAttemptRecord.completionData(FieldValue.serverTimestamp()),
    ),
  );

  /// Resolves what the student may do for [stage]. Built only on
  /// [fetchParticipant] and [fetchAttempt], so test doubles that override
  /// those get the same decision logic.
  Future<ResearchStageSnapshot> loadStage(
    String uid,
    ResearchStage stage,
  ) async {
    final participant = await fetchParticipant(uid);
    if (participant == null) {
      return const ResearchStageSnapshot(kind: ResearchStageKind.notEnrolled);
    }
    final number = participant.authorizedAttempt(stage);
    if (number < 1) {
      return ResearchStageSnapshot(
        kind: ResearchStageKind.notAuthorized,
        participant: participant,
      );
    }
    if (stage == ResearchStage.postTest) {
      final preNumber = participant.authorizedPreTest;
      final preAttempt = preNumber < 1
          ? null
          : await fetchAttempt(
              ResearchAttemptRecord.idFor(
                uid,
                ResearchStage.preTest,
                preNumber,
              ),
            );
      if (preAttempt?.status != ResearchAttemptStatus.completed) {
        return ResearchStageSnapshot(
          kind: ResearchStageKind.locked,
          participant: participant,
        );
      }
    }

    final attemptId = ResearchAttemptRecord.idFor(uid, stage, number);
    final attempt = await fetchAttempt(attemptId);
    if (attempt == null) {
      return ResearchStageSnapshot(
        kind: ResearchStageKind.notStarted,
        participant: participant,
        attemptId: attemptId,
      );
    }
    final consistent =
        attempt.studentId == uid &&
        attempt.stage == stage &&
        attempt.attemptNumber == number &&
        attempt.band == participant.assignment.band &&
        attempt.instrumentVersion == participant.assignment.instrumentVersion;
    return ResearchStageSnapshot(
      kind: !consistent
          ? ResearchStageKind.invalid
          : switch (attempt.status) {
              ResearchAttemptStatus.inProgress => ResearchStageKind.inProgress,
              ResearchAttemptStatus.completed => ResearchStageKind.completed,
              ResearchAttemptStatus.voided => ResearchStageKind.voided,
            },
      participant: participant,
      attemptId: attemptId,
      attempt: attempt,
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(timeout);
    } on TimeoutException {
      throw const ResearchServiceException(
        ResearchFailureKind.timeout,
        'no response from the server in time',
      );
    } on FirebaseException catch (error) {
      throw ResearchServiceException(switch (error.code) {
        'permission-denied' => ResearchFailureKind.permissionDenied,
        'unavailable' || 'deadline-exceeded' => ResearchFailureKind.unavailable,
        _ => ResearchFailureKind.unknown,
      }, error.code);
    } on ResearchInstrumentException catch (error) {
      throw ResearchServiceException(
        ResearchFailureKind.invalidData,
        error.message,
      );
    }
  }
}
