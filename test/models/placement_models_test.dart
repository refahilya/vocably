import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/placement_attempt.dart';
import 'package:vocably/models/placement_instrument.dart';
import 'package:vocably/models/placement_status.dart';
import 'package:vocably/models/research_participant.dart';
import 'package:vocably/models/research_study.dart';

import '../support/fake_research_assessment_service.dart' show openStudy;

void main() {
  final bankJson = File(kPlacementBankAsset).readAsStringSync();
  Map<String, dynamic> bank() => jsonDecode(bankJson) as Map<String, dynamic>;
  final instrument = PlacementInstrument.fromJson(bank());

  group('PlacementInstrument', () {
    test('the committed PT-V1.1 bank parses: 5 bands × 10 items, options A–D, one marked word each', () {
      expect(instrument.items, hasLength(50));
      for (final band in kPlacementBands) {
        expect(instrument.itemsForBand(band), hasLength(10));
      }
      for (final item in instrument.items) {
        expect(item.options.map((o) => o.id), kPlacementOptionIds);
      }
    });

    test('the app bank carries no answer-key field', () {
      expect(RegExp(r'"(key|correct\w*|answer\w*)"\s*:').hasMatch(bankJson), isFalse);
    });

    test('a malformed or mismatched bank is refused, never guessed at', () {
      final cases = <Map<String, dynamic>>[
        bank()..['instrumentVersion'] = 'PT-V1.0',
        bank()..['items'] = (bank()['items'] as List).sublist(1),
        bank()..['dontKnowOption'] = {'id': 'E', 'text': 'Tidak tahu'},
        bank()..['items'] = [
          for (final (i, item) in (bank()['items'] as List).indexed)
            i == 0 ? {...item as Map, 'sentenceMarkup': 'No marker here.'} : item,
        ],
        bank()..['items'] = [
          for (final (i, item) in (bank()['items'] as List).indexed)
            i == 3 ? {...item as Map, 'options': ((item)['options'] as List).reversed.toList()} : item,
        ],
      ];
      for (final c in cases) {
        expect(() => PlacementInstrument.fromJson(c), throwsA(isA<PlacementInstrumentException>()));
      }
    });
  });

  group('PlacementAttemptRecord', () {
    test('buildItemOrder keeps the band order and shuffles only within each band', () {
      final order = PlacementAttemptRecord.buildItemOrder(instrument, Random(1));
      expect(order.toSet(), hasLength(50));
      for (var b = 0; b < 5; b++) {
        expect(
          order.sublist(b * 10, b * 10 + 10).toSet(),
          instrument.itemsForBand(kPlacementBands[b]).map((i) => i.id).toSet(),
        );
      }
      expect(PlacementAttemptRecord.buildItemOrder(instrument, Random(2)), isNot(order));
    });

    test('payloads carry no score, flag or key field', () {
      final payloads = [
        PlacementAttemptRecord.newAttemptData(studentId: 'u', context: PlacementContext.research, attemptNumber: 1, itemOrder: const [], serverTimestamp: 'ts'),
        PlacementAttemptRecord.scoreData(PlacementResult.candidates[2], 'ts'),
        PlacementAttemptRecord.participantBandData(PlacementResult.candidates[5], 'u_research_1', 'ts'),
      ];
      for (final p in payloads) {
        expect(p.keys.where((k) => RegExp(r'score$|flag|key|correct', caseSensitive: false).hasMatch(k)), isEmpty);
      }
      expect(PlacementAttemptRecord.participantBandData(PlacementResult.candidates[5], 'id', 'ts'), {
        'band': null,
        'bandSource': null,
        'status': 'excluded',
        'exclusionReason': 'placement_c1',
        'placementAttemptId': 'id',
        'updatedAt': 'ts',
      });
    });

    test('fromFirestore is strict about status, order and answers', () {
      final order = PlacementAttemptRecord.buildItemOrder(instrument, Random(3));
      Map<String, dynamic> doc() => {
        'studentId': 'u',
        'context': 'research',
        'attemptNumber': 1,
        'instrumentVersion': kPlacementInstrumentVersion,
        'itemOrder': order,
        'answers': {order.first: 'E'},
        'status': 'in_progress',
        'tabSwitchCount': 2,
      };
      final a = PlacementAttemptRecord.fromFirestore('u_research_1', doc());
      expect(a.firstUnansweredIndex, 1);
      expect(a.tabSwitchCount, 2);
      for (final broken in [
        doc()..['status'] = 'done',
        doc()..['answers'] = {order.first: 'F'},
        doc()..['itemOrder'] = order.sublist(1),
        doc()..['context'] = 'other',
        {...doc(), 'status': 'scored', 'resultLevel': 'C2', 'belowA1Threshold': false},
      ]) {
        expect(() => PlacementAttemptRecord.fromFirestore('x', broken), throwsA(isA<PlacementInstrumentException>()));
      }
      final scored = PlacementAttemptRecord.fromFirestore('x', {
        ...doc(),
        'status': 'scored',
        'resultLevel': 'B1',
        'belowA1Threshold': false,
        'pretestTargetBand': 'B2',
        'scoredAt': Timestamp.fromDate(DateTime(2026, 10, 28)),
      });
      expect(scored.result, PlacementResult.candidates[3]);
    });
  });

  group('ResearchParticipant (pending band)', () {
    Map<String, dynamic> pending() => {
      'researchId': 'R',
      'band': null,
      'status': 'awaiting_placement',
      'instrumentVersion': 'v1',
      'authorizedAttempts': {'placement': 1, 'preTest': 0, 'postTest': 0},
      'reviewStatus': null,
    };

    test('a participant without a band is valid while awaiting placement, but cannot take research stages', () {
      final p = ResearchParticipant.fromFirestore(pending());
      expect(p.status, ResearchParticipantStatus.awaitingPlacement);
      expect(p.assignment, isNull);
      expect(p.authorizedPlacement, 1);
      expect(p.canTakeResearchStages, isFalse);
    });

    test('band/status combinations the tooling never writes are refused', () {
      for (final broken in [
        pending()..['band'] = 'B1',
        pending()..['status'] = 'enrolled',
        pending()..['status'] = 'unknown',
        pending()..['reviewStatus'] = 'maybe',
        {...pending(), 'status': 'conditional'},
      ]) {
        expect(() => ResearchParticipant.fromFirestore(broken), throwsA(anything), reason: '$broken');
      }
    });

    test('an enrolled participant under pending review cannot take research stages', () {
      final p = ResearchParticipant.fromFirestore({...pending(), 'status': 'enrolled', 'band': 'B1', 'reviewStatus': 'pending'});
      expect(p.reviewPending, isTrue);
      expect(p.canTakeResearchStages, isFalse);
    });
  });

  group('resolvePlacementStatus', () {
    const config = PlacementConfig(instrumentVersion: kPlacementInstrumentVersion, learningOpen: true);
    final now = DateTime(2026, 10, 28, 10);
    PlacementAttemptRecord attempt(PlacementContext c, int n, PlacementAttemptStatus s, {DateTime? scoredAt, String? voidCategory}) =>
        PlacementAttemptRecord(
          id: PlacementAttemptRecord.idFor('u', c, n),
          studentId: 'u',
          context: c,
          attemptNumber: n,
          instrumentVersion: kPlacementInstrumentVersion,
          itemOrder: const [],
          answers: const {},
          status: s,
          result: s == PlacementAttemptStatus.scored ? PlacementResult.candidates[2] : null,
          scoredAt: scoredAt,
          voidCategory: voidCategory,
        );
    ResearchParticipant participant(ResearchParticipantStatus status, {String? band}) => ResearchParticipant(
      status: status,
      assignment: band == null ? null : ResearchParticipantAssignment(band: band, instrumentVersion: 'v1'),
      instrumentVersion: 'v1',
      authorizedPlacement: 1,
      authorizedPreTest: 0,
      authorizedPostTest: 0,
    );
    PlacementStatus resolve({PlacementConfig? cfg = config, ResearchParticipant? p, ResearchStudy? study, List<PlacementAttemptRecord> attempts = const []}) =>
        resolvePlacementStatus(config: cfg, participant: p, study: study ?? openStudy(open: const {'placement'}), attempts: attempts, now: DateTime.now());

    test('not configured, or configured for another instrument version', () {
      expect(resolve(cfg: null), isA<PlacementBlocked>());
      expect((resolve(cfg: const PlacementConfig(instrumentVersion: 'PT-V1.0', learningOpen: true)) as PlacementBlocked).reason, PlacementBlock.notConfigured);
    });

    test('ordinary user: start when learning is open, blocked when closed', () {
      expect(resolve(), isA<PlacementCanStart>().having((s) => s.context, 'context', PlacementContext.learning));
      expect((resolve(cfg: const PlacementConfig(instrumentVersion: kPlacementInstrumentVersion, learningOpen: false)) as PlacementBlocked).reason,
          PlacementBlock.learningClosed);
    });

    test('awaiting participant: research attempt only while the placement window is open', () {
      final p = participant(ResearchParticipantStatus.awaitingPlacement);
      expect(resolve(p: p), isA<PlacementCanStart>().having((s) => s.context, 'context', PlacementContext.research));
      expect((resolve(p: p, study: openStudy(open: const {})) as PlacementBlocked).reason, PlacementBlock.researchClosed);
      final paused = resolve(p: p, study: openStudy(open: const {}), attempts: [attempt(PlacementContext.research, 1, PlacementAttemptStatus.inProgress)]);
      expect(paused, isA<PlacementResumable>().having((s) => s.open, 'open', isFalse));
    });

    test('voids: technical waits for a new attempt; integrity means contact the researcher', () {
      final p = participant(ResearchParticipantStatus.awaitingPlacement);
      expect((resolve(p: p, attempts: [attempt(PlacementContext.research, 1, PlacementAttemptStatus.voided, voidCategory: 'technical')]) as PlacementBlocked).reason,
          PlacementBlock.voidedTechnical);
      expect((resolve(p: participant(ResearchParticipantStatus.awaitingManualBand)) as PlacementBlocked).reason, PlacementBlock.contactResearcher);
    });

    test('a submitted research attempt is scored even after closure', () {
      final p = participant(ResearchParticipantStatus.awaitingPlacement);
      expect(resolve(p: p, study: openStudy(open: const {}), attempts: [attempt(PlacementContext.research, 1, PlacementAttemptStatus.submitted)]),
          isA<PlacementAwaitingScore>());
    });

    test('enrolled participant during the study keeps the official result, no retake; after closure a learning retake opens', () {
      final p = participant(ResearchParticipantStatus.enrolled, band: 'B1');
      final scored = attempt(PlacementContext.research, 1, PlacementAttemptStatus.scored, scoredAt: now.subtract(const Duration(days: 3)));
      final during = resolve(p: p, attempts: [scored]) as PlacementHasResult;
      expect(during.nextLearningAttempt, isNull);
      final closed = ResearchStudy(status: ResearchStudyStatus.closed, windows: const {});
      expect((resolve(p: p, study: closed, attempts: [scored]) as PlacementHasResult).nextLearningAttempt, 1);
    });

    test('learning retake waits a day after the previous learning result', () {
      final recent = attempt(PlacementContext.learning, 1, PlacementAttemptStatus.scored, scoredAt: DateTime.now().subtract(const Duration(hours: 2)));
      final s = resolve(attempts: [recent]) as PlacementHasResult;
      expect(s.nextLearningAttempt, isNull);
      expect(s.retakeAvailableAt, isNotNull);
      final old = attempt(PlacementContext.learning, 1, PlacementAttemptStatus.scored, scoredAt: DateTime.now().subtract(const Duration(days: 2)));
      expect((resolve(attempts: [old]) as PlacementHasResult).nextLearningAttempt, 2);
    });
  });
}
