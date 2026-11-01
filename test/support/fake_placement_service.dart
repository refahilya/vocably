import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vocably/models/placement_attempt.dart';
import 'package:vocably/models/placement_instrument.dart';
import 'package:vocably/models/placement_status.dart';
import 'package:vocably/models/research_participant.dart';
import 'package:vocably/models/research_study.dart';
import 'package:vocably/services/placement_service.dart';
import 'package:vocably/services/research_assessment_service.dart';

import 'fake_research_assessment_service.dart' show FakeFault, FakeFaultSpec, openStudy;

/// In-memory stand-in for the placement collections that enforces the same
/// decisions as `firestore.rules` for the operations the app performs
/// (create only when allowed, answers while in progress and writable,
/// submit with 50 answers, score only the exact K2 result once). The key
/// is SYNTHETIC (letter by item number). The real rules are tested against
/// the emulator, including replays of the app's exact payloads.
class FakePlacementService extends PlacementService {
  FakePlacementService({
    this.config = const PlacementConfig(instrumentVersion: kPlacementInstrumentVersion, learningOpen: true),
    this.participant,
    ResearchStudy? study,
  }) : study = study ?? openStudy(open: const {'placement', 'preTest', 'postTest'});

  PlacementConfig? config;
  ResearchParticipant? participant;
  ResearchStudy study;
  final attempts = <String, PlacementAttemptRecord>{};
  final writeFaults = <FakeFaultSpec?>[];
  final readFaults = <ResearchFailureKind>[];
  Completer<void>? holdWrites;

  /// When set, the participant band write is refused (e.g. pending review).
  bool refuseBandWrite = false;

  int createCalls = 0;
  int saveCalls = 0;
  int submitCalls = 0;
  int scoreCalls = 0;
  int hiddenCalls = 0;
  String? userResultLevel;
  String? userResultAttemptId;

  PlacementInstrument? _instrument;

  static String keyOf(PlacementItem item) => kPlacementOptionIds[item.number % 4];

  /// Read synchronously from the committed asset file: `rootBundle` caches
  /// its futures across widget tests, which never complete in a later
  /// test's fake-async zone.
  @override
  Future<PlacementInstrument> loadInstrument() async =>
      _instrument ??= PlacementInstrument.fromJson(jsonDecode(File(kPlacementBankAsset).readAsStringSync()));

  void _read() {
    if (readFaults.isNotEmpty) throw ResearchServiceException(readFaults.removeAt(0), 'fake read fault');
  }

  static Never _deny(String why) => throw ResearchServiceException(ResearchFailureKind.permissionDenied, why);

  Future<void> _write(void Function() apply) async {
    final hold = holdWrites;
    if (hold != null) await hold.future;
    final fault = writeFaults.isEmpty ? null : writeFaults.removeAt(0);
    if (fault?.fault == FakeFault.failBefore) throw ResearchServiceException(fault!.kind, 'fake fault');
    apply();
    if (fault?.fault == FakeFault.applyThenFail) throw ResearchServiceException(fault!.kind, 'fake fault');
  }

  bool _writable(PlacementAttemptRecord a) {
    if (a.context == PlacementContext.learning) return config?.learningOpen == true;
    final p = participant;
    return p != null &&
        p.status == ResearchParticipantStatus.awaitingPlacement &&
        p.authorizedPlacement == a.attemptNumber &&
        !p.reviewPending &&
        study.stageOpen(ResearchStageIds.placement, DateTime.now());
  }

  @override
  Future<PlacementConfig?> fetchConfig() async {
    _read();
    return config;
  }

  @override
  Future<ResearchStudy> fetchStudy() async => study;

  @override
  Future<ResearchParticipant?> fetchParticipant(String uid) async {
    _read();
    return participant;
  }

  @override
  Future<List<PlacementAttemptRecord>> fetchOwnAttempts(String uid) async {
    _read();
    return [for (final a in attempts.values) if (a.studentId == uid) a];
  }

  /// Like the real rules, refuses a `get` on a document that does not exist:
  /// `resource.data` has no value to evaluate there (`firestore.rules`,
  /// `placementAttempts`; `placementClientFlow.test.js` checks it against the
  /// emulator). Only the own-attempts query can see that an attempt is absent.
  @override
  Future<PlacementAttemptRecord?> fetchAttempt(String id) async {
    _read();
    return attempts[id] ?? _deny('missing attempt');
  }

  @override
  Future<void> createAttempt({
    required String studentId,
    required PlacementContext context,
    required int attemptNumber,
    required List<String> itemOrder,
  }) async {
    createCalls++;
    await _write(() {
      final id = PlacementAttemptRecord.idFor(studentId, context, attemptNumber);
      if (attempts.containsKey(id)) _deny('exists');
      final record = PlacementAttemptRecord(
        id: id,
        studentId: studentId,
        context: context,
        attemptNumber: attemptNumber,
        instrumentVersion: kPlacementInstrumentVersion,
        itemOrder: itemOrder,
        answers: const {},
        status: PlacementAttemptStatus.inProgress,
      );
      if (!_writable(record)) _deny('not allowed');
      final instrument = _instrument!;
      for (var b = 0; b < kPlacementBands.length; b++) {
        final slice = itemOrder.sublist(b * 10, b * 10 + 10).toSet();
        if (!slice.containsAll(instrument.itemsForBand(kPlacementBands[b]).map((i) => i.id)) || slice.length != 10) {
          _deny('bad order');
        }
      }
      attempts[id] = record;
    });
  }

  @override
  Future<void> saveAnswer({required String attemptId, required String itemId, required String answer}) async {
    saveCalls++;
    await _write(() {
      final a = attempts[attemptId];
      if (a == null || a.status != PlacementAttemptStatus.inProgress || !_writable(a)) _deny('frozen');
      if (!a.itemOrder.contains(itemId) || !kPlacementAnswerIds.contains(answer)) _deny('bad answer');
      attempts[attemptId] = a.copyWith(answers: {...a.answers, itemId: answer});
    });
  }

  @override
  Future<void> recordHidden(String attemptId, int newCount) async {
    hiddenCalls++;
    await _write(() {
      final a = attempts[attemptId];
      if (a == null || a.status != PlacementAttemptStatus.inProgress || newCount != a.tabSwitchCount + 1) _deny('counter');
      attempts[attemptId] = a.copyWith(tabSwitchCount: newCount);
    });
  }

  @override
  Future<void> submit(String attemptId) async {
    submitCalls++;
    await _write(() {
      final a = attempts[attemptId];
      if (a == null || a.status != PlacementAttemptStatus.inProgress || !_writable(a) || !a.allAnswered) _deny('submit');
      attempts[attemptId] = a.copyWith(status: PlacementAttemptStatus.submitted);
    });
  }

  /// The K2 decision under the synthetic key (what the rules recompute).
  PlacementResult expectedResult(PlacementAttemptRecord a) {
    final instrument = _instrument!;
    final s = [
      for (final band in kPlacementBands)
        instrument.itemsForBand(band).where((i) => a.answers[i.id] == keyOf(i)).length,
    ];
    var level = -1;
    for (var k = 0; k < 5; k++) {
      if (s[k] < 7) continue;
      var ok = true;
      var atSix = 0;
      for (var j = 0; j < k; j++) {
        if (s[j] < 6) {
          ok = false;
        } else if (s[j] < 7) {
          atSix++;
        }
      }
      if (ok && atSix <= 1) level = k;
    }
    return PlacementResult.candidates[level + 1];
  }

  @override
  Future<PlacementResult?> score(PlacementAttemptRecord attempt) async {
    scoreCalls++;
    PlacementResult? accepted;
    await _write(() {
      final a = attempts[attempt.id];
      if (a == null || a.status != PlacementAttemptStatus.submitted) return;
      if (a.context == PlacementContext.research &&
          (refuseBandWrite || participant?.status != ResearchParticipantStatus.awaitingPlacement)) {
        return;
      }
      final result = expectedResult(a);
      attempts[a.id] = PlacementAttemptRecord(
        id: a.id,
        studentId: a.studentId,
        context: a.context,
        attemptNumber: a.attemptNumber,
        instrumentVersion: a.instrumentVersion,
        itemOrder: a.itemOrder,
        answers: a.answers,
        status: PlacementAttemptStatus.scored,
        tabSwitchCount: a.tabSwitchCount,
        result: result,
        scoredAt: DateTime.now(),
      );
      userResultLevel = result.resultLevel;
      userResultAttemptId = a.id;
      if (a.context == PlacementContext.research) {
        final band = result.pretestTargetBand;
        participant = ResearchParticipant(
          status: band == null ? ResearchParticipantStatus.excluded : ResearchParticipantStatus.enrolled,
          assignment: band == null ? null : ResearchParticipantAssignment(band: band, instrumentVersion: 'v1'),
          instrumentVersion: 'v1',
          authorizedPlacement: participant!.authorizedPlacement,
          authorizedPreTest: participant!.authorizedPreTest,
          authorizedPostTest: participant!.authorizedPostTest,
        );
      }
      accepted = result;
    });
    return accepted;
  }

  /// Answers giving band scores [s] under the synthetic key (rest E).
  Map<String, String> answersFor(List<int> s) {
    final instrument = _instrument!;
    return {
      for (var b = 0; b < 5; b++)
        for (final (i, item) in instrument.itemsForBand(kPlacementBands[b]).indexed)
          item.id: i < s[b] ? keyOf(item) : kPlacementDontKnowId,
    };
  }
}

ResearchParticipant pendingParticipant({int placement = 1, bool reviewPending = false}) => ResearchParticipant(
  status: ResearchParticipantStatus.awaitingPlacement,
  assignment: null,
  instrumentVersion: 'v1',
  authorizedPlacement: placement,
  authorizedPreTest: 0,
  authorizedPostTest: 0,
  reviewPending: reviewPending,
);
