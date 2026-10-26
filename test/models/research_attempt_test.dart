import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' show FieldPath;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/models/research_attempt.dart';
import 'package:vocably/models/research_attempt_plan.dart';
import 'package:vocably/models/research_instrument.dart';
import 'package:vocably/models/research_participant.dart';
import 'package:vocably/utils/research_attempt_planner.dart';

const _ts = '__serverTimestamp__';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ResearchInstrument instrument;
  late ResearchAttemptPlan plan;

  setUpAll(() async {
    instrument = ResearchInstrument.fromJson(
      jsonDecode(
        await rootBundle.loadString('assets/research/instrument_v1.json'),
      ),
      expectedVersion: 'v1',
    );
    plan = planResearchAttempt(
      instrument: instrument,
      assignment: const ResearchParticipantAssignment(
        band: 'A2',
        instrumentVersion: 'v1',
      ),
      random: Random(5),
    );
  });

  Matcher throwsInstrumentError() =>
      throwsA(isA<ResearchInstrumentException>());

  Map<String, dynamic> storedAttempt({
    String uid = 'stu1',
    Map<String, dynamic> responses = const {},
    String status = 'in_progress',
  }) => {
    ...ResearchAttemptRecord.newAttemptData(
      studentId: uid,
      stage: ResearchStage.preTest,
      attemptNumber: 1,
      plan: plan,
      serverTimestamp: _ts,
    ),
    'responses': responses,
    'status': status,
  };

  group('ResearchResponse.forPlannedItem', () {
    test('position is the display index + 1 and the text is the bank text', () {
      final item = plan.items.first;
      for (var i = 0; i < 4; i++) {
        final option = item.substantiveOptions[i];
        final response = ResearchResponse.forPlannedItem(item, option.id);
        expect(response.displayPosition, i + 1);
        expect(response.optionText, option.text);
      }
    });

    test('"Saya tidak tahu kata ini" is always position 5', () {
      final response = ResearchResponse.forPlannedItem(
        plan.items.first,
        'dont_know',
      );
      expect(response.displayPosition, 5);
      expect(response.optionText, 'Saya tidak tahu kata ini');
    });

    test('rejects an option that is not displayed for the item', () {
      final other = plan.items[1].substantiveOptions.first.id;
      expect(
        () => ResearchResponse.forPlannedItem(plan.items.first, other),
        throwsInstrumentError(),
      );
    });

    test('matches only an answer consistent with the stored order', () {
      final item = plan.items.first;
      final good = ResearchResponse.forPlannedItem(
        item,
        item.substantiveOptions[2].id,
      );
      expect(good.matches(item), isTrue);
      expect(
        ResearchResponse(
          optionId: good.optionId,
          optionText: good.optionText,
          displayPosition: 1,
        ).matches(item),
        isFalse,
      );
      expect(
        ResearchResponse(
          optionId: good.optionId,
          optionText: 'Teks lain',
          displayPosition: 3,
        ).matches(item),
        isFalse,
      );
    });
  });

  group('payloads match the research rules field lists', () {
    test('a new attempt has exactly the rules\' 13 fields', () {
      final data = ResearchAttemptRecord.newAttemptData(
        studentId: 'stu1',
        stage: ResearchStage.preTest,
        attemptNumber: 1,
        plan: plan,
        serverTimestamp: _ts,
      );
      expect(data.keys.toSet(), {
        'studentId',
        'stage',
        'attemptNumber',
        'band',
        'instrumentVersion',
        'itemOrder',
        'optionOrder',
        'responses',
        'lastAnsweredItemId',
        'status',
        'startedAt',
        'updatedAt',
        'completedAt',
      });
      expect(data['status'], 'in_progress');
      expect(data['responses'], isEmpty);
      expect(data['lastAnsweredItemId'], isNull);
      expect(data['completedAt'], isNull);
      expect(data['startedAt'], _ts);
      expect(data['itemOrder'], plan.itemOrder);
      expect(data['optionOrder'], plan.optionOrder);
    });

    test(
      'an answer update touches only responses.<item>, lastAnsweredItemId and updatedAt',
      () {
        final item = plan.items.first;
        final data = ResearchAttemptRecord.answerUpdateData(
          itemId: item.itemId,
          response: ResearchResponse.forPlannedItem(item, 'dont_know'),
          serverTimestamp: _ts,
        );
        expect(data, hasLength(3));
        final path = data.keys.whereType<FieldPath>().single;
        expect(path.components, ['responses', item.itemId]);
        expect(data[path], {
          'optionId': 'dont_know',
          'optionText': 'Saya tidak tahu kata ini',
          'displayPosition': 5,
          'answeredAt': _ts,
        });
        expect(data['lastAnsweredItemId'], item.itemId);
        expect(data['updatedAt'], _ts);
      },
    );

    test('completion sets only status, completedAt and updatedAt', () {
      expect(ResearchAttemptRecord.completionData(_ts), {
        'status': 'completed',
        'completedAt': _ts,
        'updatedAt': _ts,
      });
    });
  });

  group('ResearchAttemptRecord.fromFirestore', () {
    test('parses a stored attempt, including tooling-only void fields', () {
      final item = plan.items.first;
      final record = ResearchAttemptRecord.fromFirestore('stu1_preTest_1', {
        ...storedAttempt(
          responses: {
            item.itemId: ResearchResponse.forPlannedItem(
              item,
              'dont_know',
            ).toFirestore(_ts),
          },
          status: 'voided',
        ),
        'voidReason': 'gangguan teknis',
        'voidedAt': _ts,
      });
      expect(record.stage, ResearchStage.preTest);
      expect(record.status, ResearchAttemptStatus.voided);
      expect(record.itemOrder, plan.itemOrder);
      expect(record.responses.keys, [item.itemId]);
      expect(record.allItemsAnswered, isFalse);
    });

    test(
      'rejects an id that does not belong to the stored owner/stage/number',
      () {
        expect(
          () => ResearchAttemptRecord.fromFirestore(
            'other_preTest_1',
            storedAttempt(),
          ),
          throwsInstrumentError(),
        );
        expect(
          () => ResearchAttemptRecord.fromFirestore(
            'stu1_preTest_2',
            storedAttempt(),
          ),
          throwsInstrumentError(),
        );
      },
    );

    test('rejects unknown fields such as a score or correctness flag', () {
      expect(
        () => ResearchAttemptRecord.fromFirestore('stu1_preTest_1', {
          ...storedAttempt(),
          'score': 12,
        }),
        throwsInstrumentError(),
      );
    });

    test('rejects malformed metadata, orders and answers', () {
      for (final broken in <Map<String, dynamic>>[
        {...storedAttempt(), 'status': 'done'},
        {...storedAttempt(), 'stage': 'midTest'},
        {...storedAttempt(), 'attemptNumber': 0},
        {...storedAttempt(), 'itemOrder': 'A2-01'},
        {
          ...storedAttempt(),
          'optionOrder': {'A2-01': 'opt'},
        },
        {
          ...storedAttempt(),
          'responses': {
            'A2-01': {'optionId': 'x'},
          },
        },
      ]) {
        expect(
          () => ResearchAttemptRecord.fromFirestore('stu1_preTest_1', broken),
          throwsInstrumentError(),
          reason: '$broken',
        );
      }
    });

    test('idFor builds {uid}_{stage}_{n}', () {
      expect(
        ResearchAttemptRecord.idFor('abc', ResearchStage.postTest, 2),
        'abc_postTest_2',
      );
    });
  });

  group('ResearchParticipant.fromFirestore', () {
    Map<String, dynamic> record() => {
      'researchId': 'R-01',
      'band': 'B1',
      'bandSource': 'researcher_assigned',
      'instrumentVersion': 'v1',
      'authorizedAttempts': {'preTest': 1, 'postTest': 0},
      'cohort': 'test',
    };

    test('reads the assignment and authorized attempt numbers', () {
      final p = ResearchParticipant.fromFirestore(record());
      expect(p.assignment.band, 'B1');
      expect(p.assignment.instrumentVersion, 'v1');
      expect(p.authorizedAttempt(ResearchStage.preTest), 1);
      expect(p.authorizedAttempt(ResearchStage.postTest), 0);
    });

    test('rejects a record with missing or malformed fields', () {
      for (final broken in <Map<String, dynamic>>[
        {...record()}..remove('band'),
        {...record(), 'instrumentVersion': ''},
        {...record()}..remove('authorizedAttempts'),
        {
          ...record(),
          'authorizedAttempts': {'preTest': '1', 'postTest': 0},
        },
        {
          ...record(),
          'authorizedAttempts': {'preTest': -1, 'postTest': 0},
        },
      ]) {
        expect(
          () => ResearchParticipant.fromFirestore(broken),
          throwsInstrumentError(),
          reason: '$broken',
        );
      }
    });
  });
}
