import 'dart:async';

import 'package:vocably/models/research_attempt.dart';
import 'package:vocably/models/research_attempt_plan.dart';
import 'package:vocably/models/research_participant.dart';
import 'package:vocably/services/research_assessment_service.dart';
import 'package:vocably/utils/research_constants.dart';

/// How the next write (or read) misbehaves.
enum FakeFault {
  /// Throws [kind] without applying the write (the request never landed).
  failBefore,

  /// Applies the write, then throws [kind] (the acknowledgement was lost).
  applyThenFail,
}

class FakeFaultSpec {
  const FakeFaultSpec(this.fault, this.kind);

  final FakeFault fault;
  final ResearchFailureKind kind;
}

/// In-memory stand-in for the research collections that enforces the same
/// decisions as `firestore.rules` for the operations the app performs:
/// - create only when absent, authorized, and (posttest) pretest completed;
/// - answer only while in progress, on the authorized attempt, once per item,
///   with an option displayed for that item at its displayed position;
/// - complete only with all 20 answers.
/// A refusal throws [ResearchFailureKind.permissionDenied], as the real
/// service does. Faults can be queued to simulate network problems.
///
/// The real rules are exercised separately against the Firestore Emulator
/// (`tools/research/test/rules/`), including replays of these exact
/// payloads.
class FakeResearchAssessmentService extends ResearchAssessmentService {
  FakeResearchAssessmentService({this.participant});

  ResearchParticipant? participant;
  final attempts = <String, ResearchAttemptRecord>{};

  /// Consumed one per write, in order; `null` = that write behaves normally.
  final writeFaults = <FakeFaultSpec?>[];
  final readFaults = <ResearchFailureKind>[];

  int createCalls = 0;
  int saveCalls = 0;
  int completeCalls = 0;
  int readCalls = 0;

  /// Runs just before a write is evaluated (to simulate another tab).
  void Function()? beforeNextWrite;

  void _maybeFailRead() {
    readCalls++;
    if (readFaults.isNotEmpty) {
      throw ResearchServiceException(readFaults.removeAt(0), 'fake read fault');
    }
  }

  /// While set, writes wait for it to complete (to observe "saving" states).
  Completer<void>? holdWrites;

  /// Thrown as-is by the next write (an error the service doesn't map).
  Object? unexpectedNextWriteError;

  Future<void> _write(void Function() apply) async {
    final hold = holdWrites;
    if (hold != null) await hold.future;
    final unexpected = unexpectedNextWriteError;
    if (unexpected != null) {
      unexpectedNextWriteError = null;
      throw unexpected;
    }
    final hook = beforeNextWrite;
    beforeNextWrite = null;
    hook?.call();
    final fault = writeFaults.isEmpty ? null : writeFaults.removeAt(0);
    if (fault?.fault == FakeFault.failBefore) {
      throw ResearchServiceException(fault!.kind, 'fake write fault');
    }
    apply();
    if (fault?.fault == FakeFault.applyThenFail) {
      throw ResearchServiceException(fault!.kind, 'fake lost ack');
    }
  }

  static Never _deny(String why) =>
      throw ResearchServiceException(ResearchFailureKind.permissionDenied, why);

  @override
  Future<ResearchParticipant?> fetchParticipant(String uid) async {
    _maybeFailRead();
    return participant;
  }

  @override
  Future<ResearchAttemptRecord?> fetchAttempt(String attemptId) async {
    _maybeFailRead();
    return attempts[attemptId];
  }

  @override
  Future<void> createAttempt({
    required String studentId,
    required ResearchStage stage,
    required int attemptNumber,
    required ResearchAttemptPlan plan,
  }) async {
    createCalls++;
    await _write(() {
      final id = ResearchAttemptRecord.idFor(studentId, stage, attemptNumber);
      final p = participant;
      if (attempts.containsKey(id)) _deny('exists');
      if (p == null || p.authorizedAttempt(stage) != attemptNumber) {
        _deny('not authorized');
      }
      if (plan.band != p.assignment.band ||
          plan.instrumentVersion != p.assignment.instrumentVersion) {
        _deny('assignment mismatch');
      }
      if (stage == ResearchStage.postTest) {
        final pre =
            attempts[ResearchAttemptRecord.idFor(
              studentId,
              ResearchStage.preTest,
              p.authorizedPreTest,
            )];
        if (pre?.status != ResearchAttemptStatus.completed) {
          _deny('pretest not completed');
        }
      }
      attempts[id] = ResearchAttemptRecord(
        attemptId: id,
        studentId: studentId,
        stage: stage,
        attemptNumber: attemptNumber,
        band: plan.band,
        instrumentVersion: plan.instrumentVersion,
        itemOrder: plan.itemOrder,
        optionOrder: plan.optionOrder,
        responses: const {},
        status: ResearchAttemptStatus.inProgress,
      );
    });
  }

  bool _authorized(ResearchAttemptRecord a) =>
      participant?.authorizedAttempt(a.stage) == a.attemptNumber;

  @override
  Future<void> saveAnswer({
    required String attemptId,
    required String itemId,
    required ResearchResponse response,
  }) async {
    saveCalls++;
    await _write(() {
      final a = attempts[attemptId];
      if (a == null || a.status != ResearchAttemptStatus.inProgress) {
        _deny('not in progress');
      }
      if (!_authorized(a)) _deny('superseded');
      if (!a.itemOrder.contains(itemId)) _deny('unknown item');
      if (a.responses.containsKey(itemId)) _deny('already answered');
      final order = a.optionOrder[itemId]!;
      final validPosition = response.optionId == kResearchDontKnowOptionId
          ? response.displayPosition == 5 &&
                response.optionText == kResearchDontKnowOptionText
          : order.indexOf(response.optionId) + 1 == response.displayPosition &&
                response.displayPosition >= 1;
      if (!validPosition) _deny('invalid answer');
      attempts[attemptId] = _copy(
        a,
        responses: {...a.responses, itemId: response},
      );
    });
  }

  @override
  Future<void> completeAttempt(String attemptId) async {
    completeCalls++;
    await _write(() {
      final a = attempts[attemptId];
      if (a == null || a.status != ResearchAttemptStatus.inProgress) {
        _deny('not in progress');
      }
      if (!_authorized(a)) _deny('superseded');
      if (!a.allItemsAnswered) _deny('not all answered');
      attempts[attemptId] = _copy(a, status: ResearchAttemptStatus.completed);
    });
  }

  /// Trusted-tooling style edits used by tests (bypass the "rules").
  void putAttempt(ResearchAttemptRecord record) =>
      attempts[record.attemptId] = record;

  static ResearchAttemptRecord _copy(
    ResearchAttemptRecord a, {
    Map<String, ResearchResponse>? responses,
    ResearchAttemptStatus? status,
    String? band,
  }) => ResearchAttemptRecord(
    attemptId: a.attemptId,
    studentId: a.studentId,
    stage: a.stage,
    attemptNumber: a.attemptNumber,
    band: band ?? a.band,
    instrumentVersion: a.instrumentVersion,
    itemOrder: a.itemOrder,
    optionOrder: a.optionOrder,
    responses: responses ?? a.responses,
    status: status ?? a.status,
  );

  ResearchAttemptRecord copyAttempt(
    ResearchAttemptRecord a, {
    Map<String, ResearchResponse>? responses,
    ResearchAttemptStatus? status,
    String? band,
  }) => _copy(a, responses: responses, status: status, band: band);
}

ResearchParticipant participantFor({
  String band = 'A2',
  int preTest = 1,
  int postTest = 0,
}) => ResearchParticipant(
  assignment: ResearchParticipantAssignment(
    band: band,
    instrumentVersion: 'v1',
  ),
  authorizedPreTest: preTest,
  authorizedPostTest: postTest,
);
