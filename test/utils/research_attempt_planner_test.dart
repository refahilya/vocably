import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/models/research_attempt_plan.dart';
import 'package:vocably/models/research_instrument.dart';
import 'package:vocably/models/research_participant.dart';
import 'package:vocably/utils/research_attempt_planner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ResearchInstrument instrument;

  setUpAll(() async {
    instrument = ResearchInstrument.fromJson(
      jsonDecode(
        await rootBundle.loadString('assets/research/instrument_v1.json'),
      ),
      expectedVersion: 'v1',
    );
  });

  ResearchParticipantAssignment assignment([String band = 'B1']) =>
      ResearchParticipantAssignment(band: band, instrumentVersion: 'v1');

  ResearchAttemptPlan plan({String band = 'B1', int seed = 7}) =>
      planResearchAttempt(
        instrument: instrument,
        assignment: assignment(band),
        random: Random(seed),
      );

  /// A plan's public shape as plain data, for comparisons and the
  /// no-key-fields check.
  Map<String, Object?> planData(ResearchAttemptPlan p) => {
    'band': p.band,
    'instrumentVersion': p.instrumentVersion,
    'items': [
      for (final item in p.items)
        {
          'itemId': item.itemId,
          'word': item.word,
          'pos': item.pos,
          'posLabel': item.posLabel,
          'displayOptions': [
            for (final option in item.displayOptions)
              {'id': option.id, 'text': option.text},
          ],
        },
    ],
  };

  Matcher throwsInstrumentError(String messagePart) => throwsA(
    isA<ResearchInstrumentException>().having(
      (e) => e.message,
      'message',
      contains(messagePart),
    ),
  );

  group('planResearchAttempt', () {
    for (final band in ['A2', 'B1', 'B2', 'C1']) {
      test(
        '$band: exactly the band\'s 20 items, each once, each with its 4 options once',
        () {
          final p = plan(band: band);
          final bandItems = {
            for (final item in instrument.itemsForBand(band)) item.id: item,
          };

          expect(p.band, band);
          expect(p.instrumentVersion, 'v1');
          expect(p.items, hasLength(20));
          expect(p.itemOrder.toSet(), bandItems.keys.toSet());
          for (final planned in p.items) {
            final source = bandItems[planned.itemId]!;
            expect(planned.word, source.word);
            expect(planned.posLabel, source.posLabel);
            expect(planned.substantiveOptions, hasLength(4));
            expect(
              planned.substantiveOptions.map((o) => o.id).toSet(),
              source.options.map((o) => o.id).toSet(),
              reason: planned.itemId,
            );
            // Same option ID always carries the bank's text for that option.
            final textById = {for (final o in source.options) o.id: o.text};
            for (final option in planned.substantiveOptions) {
              expect(option.text, textById[option.id]);
            }
          }
        },
      );
    }

    test(
      '"Saya tidak tahu kata ini" is separate and always displayed last',
      () {
        for (var seed = 0; seed < 20; seed++) {
          for (final item in plan(seed: seed).items) {
            expect(
              item.substantiveOptions.any((o) => o.id == 'dont_know'),
              isFalse,
            );
            expect(item.displayOptions, hasLength(5));
            expect(item.displayOptions.last.id, 'dont_know');
            expect(item.displayOptions.last.text, 'Saya tidak tahu kata ini');
            expect(
              item.displayOptions.take(4).toList(),
              item.substantiveOptions,
            );
          }
        }
      },
    );

    test('the same seed always gives the same plan', () {
      for (final seed in [0, 1, 42, 9999]) {
        expect(
          planData(plan(seed: seed)),
          planData(plan(seed: seed)),
          reason: 'seed $seed',
        );
      }
    });

    test('item and option orders are actually shuffled across seeds', () {
      final sourceItemOrder = [
        for (final item in instrument.itemsForBand('B1')) item.id,
      ];
      final sourceOptionOrder = {
        for (final item in instrument.itemsForBand('B1'))
          item.id: [for (final o in item.options) o.id],
      };
      final firstItems = <String>{};
      final firstOptionsPerItem = <String, Set<String>>{};
      var plansInSourceOrder = 0;

      for (var seed = 0; seed < 200; seed++) {
        final p = plan(seed: seed);
        if (listEquals(p.itemOrder, sourceItemOrder)) plansInSourceOrder++;
        firstItems.add(p.itemOrder.first);
        p.optionOrder.forEach((itemId, ids) {
          firstOptionsPerItem.putIfAbsent(itemId, () => {}).add(ids.first);
        });
      }

      // A real shuffle puts many different items first, and every option
      // of every item first at least once, over 200 seeds. Fixed or
      // source-order output can't.
      expect(plansInSourceOrder, 0);
      expect(firstItems.length, greaterThanOrEqualTo(15));
      for (final itemId in sourceItemOrder) {
        expect(
          firstOptionsPerItem[itemId],
          sourceOptionOrder[itemId]!.toSet(),
          reason: itemId,
        );
      }
    });

    test(
      'rejects an assignment for another instrument version or an unknown band',
      () {
        expect(
          () => planResearchAttempt(
            instrument: instrument,
            assignment: const ResearchParticipantAssignment(
              band: 'B1',
              instrumentVersion: 'v2',
            ),
            random: Random(1),
          ),
          throwsInstrumentError('assignment is for instrument "v2"'),
        );
        expect(() => plan(band: 'C2'), throwsInstrumentError('band "C2"'));
        expect(() => plan(band: 'b1'), throwsInstrumentError('band "b1"'));
      },
    );

    test('plans carry no answer-key, correctness or score data', () {
      final forbidden = RegExp(
        r'correct|answer|key|letter|score|isright|solution',
        caseSensitive: false,
      );
      List<String> forbiddenKeys(Object? value) => switch (value) {
        Map() => [
          for (final entry in value.entries) ...[
            if (forbidden.hasMatch('${entry.key}')) '${entry.key}',
            ...forbiddenKeys(entry.value),
          ],
        ],
        List() => [for (final element in value) ...forbiddenKeys(element)],
        _ => const [],
      };
      final p = plan();
      expect(forbiddenKeys(planData(p)), isEmpty);
      expect(forbiddenKeys(p.optionOrder), isEmpty);
    });
  });

  group('the research model and planner sources', () {
    test('declare no answer-key, correctness or score members', () {
      // Comments are skipped: they explain that no key is present.
      final forbidden = RegExp(
        r'correct|answerkey|answer_key|isright|score|solution|keyletter',
        caseSensitive: false,
      );
      for (final path in [
        'lib/models/research_instrument.dart',
        'lib/models/research_participant.dart',
        'lib/models/research_attempt_plan.dart',
        'lib/utils/research_attempt_planner.dart',
        'lib/utils/research_constants.dart',
        'lib/services/research_instrument_service.dart',
      ]) {
        final code = File(path)
            .readAsLinesSync()
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        expect(forbidden.hasMatch(code), isFalse, reason: path);
      }
    });
  });

  group('ResearchAttemptPlan.fromOrder', () {
    test('restores exactly the stored order', () {
      final original = plan(seed: 3);
      final restored = ResearchAttemptPlan.fromOrder(
        instrument: instrument,
        assignment: assignment(),
        itemOrder: original.itemOrder,
        optionOrder: original.optionOrder,
      );
      expect(planData(restored), planData(original));
    });

    ResearchAttemptPlan restore(
      List<String> itemOrder,
      Map<String, List<String>> optionOrder,
    ) => ResearchAttemptPlan.fromOrder(
      instrument: instrument,
      assignment: assignment(),
      itemOrder: itemOrder,
      optionOrder: optionOrder,
    );

    test(
      'rejects an item order that is not the band\'s 20 items exactly once',
      () {
        final p = plan();
        final order = p.itemOrder;
        expect(
          () => restore(order.sublist(1), p.optionOrder),
          throwsInstrumentError('item order'),
        );
        expect(
          () => restore([order[1], ...order.sublist(1)], p.optionOrder),
          throwsInstrumentError('item order'),
        );
        expect(
          () => restore(['A2-01', ...order.sublist(1)], p.optionOrder),
          throwsInstrumentError('item order'),
        );
      },
    );

    test(
      'rejects option orders that are missing, extra, or not a permutation',
      () {
        final p = plan();
        final first = p.itemOrder.first;
        expect(
          () => restore(p.itemOrder, {...p.optionOrder}..remove(first)),
          throwsInstrumentError('one entry per planned item'),
        );
        expect(
          () => restore(p.itemOrder, {
            ...p.optionOrder,
            'A2-01': p.optionOrder[first]!,
          }),
          throwsInstrumentError('one entry per planned item'),
        );
        final ids = p.optionOrder[first]!;
        for (final bad in [
          ids.sublist(1),
          [ids[0], ...ids.sublist(1, 3), ids[0]],
          [...ids.sublist(0, 3), 'dont_know'],
          [...ids, 'dont_know'],
        ]) {
          expect(
            () => restore(p.itemOrder, {...p.optionOrder, first: bad}),
            throwsInstrumentError('option order for $first'),
          );
        }
      },
    );

    test('restores a hand-written stored order exactly, positions included', () {
      // Independent of the planner: reverse the bank's item order and every
      // item's option order, as a previously saved attempt might hold.
      final bandItems = instrument.itemsForBand('B1');
      final storedItems = [for (final item in bandItems.reversed) item.id];
      final storedOptions = {
        for (final item in bandItems)
          item.id: [for (final o in item.options.reversed) o.id],
      };
      final restored = restore(storedItems, storedOptions);

      expect(restored.itemOrder, storedItems);
      expect(restored.optionOrder, storedOptions);
      for (final item in restored.items) {
        // displayOptions[i] is what the rules record as displayPosition i + 1.
        expect(
          [for (final o in item.displayOptions) o.id],
          [...storedOptions[item.itemId]!, 'dont_know'],
        );
      }
    });

    test('a restored plan does not change if the stored lists are mutated', () {
      final p = plan();
      final itemOrder = [...p.itemOrder];
      final optionOrder = {
        for (final e in p.optionOrder.entries) e.key: [...e.value],
      };
      final restored = restore(itemOrder, optionOrder);
      itemOrder.setAll(0, itemOrder.reversed.toList());
      optionOrder.values.first.setAll(
        0,
        optionOrder.values.first.reversed.toList(),
      );

      expect(restored.itemOrder, p.itemOrder);
      expect(restored.optionOrder, p.optionOrder);
    });

    test('rejects an over-long item order and a borrowed option id', () {
      final p = plan();
      final order = p.itemOrder;
      expect(
        () => restore([...order, order[0]], p.optionOrder),
        throwsInstrumentError('item order'),
      );
      final first = order.first;
      final ids = p.optionOrder[first]!;
      final otherItemOption = p.optionOrder[order[1]]!.first;
      expect(
        () => restore(order, {
          ...p.optionOrder,
          first: [...ids.sublist(0, 3), otherItemOption],
        }),
        throwsInstrumentError('option order for $first'),
      );
    });

    test('rejects a stored order restored under a different band', () {
      final p = plan(band: 'B1');
      expect(
        () => ResearchAttemptPlan.fromOrder(
          instrument: instrument,
          assignment: assignment('A2'),
          itemOrder: p.itemOrder,
          optionOrder: p.optionOrder,
        ),
        throwsInstrumentError('item order must list each A2 item'),
      );
    });
  });

  group('firstUnansweredIndex', () {
    test('no answers: resumes at the first item', () {
      expect(plan().firstUnansweredIndex(const []), 0);
    });

    test('some answers in plan order: resumes at the next item', () {
      final p = plan();
      expect(p.firstUnansweredIndex(p.itemOrder.take(5)), 5);
    });

    test(
      'answers out of order: the first gap in plan order, not the answer count',
      () {
        final p = plan();
        final order = p.itemOrder;
        // Items 0, 1, 3 and 7 answered (4 answers): the first gap is index 2.
        expect(
          p.firstUnansweredIndex([order[7], order[3], order[0], order[1]]),
          2,
        );
        // Everything except index 4 answered.
        expect(p.firstUnansweredIndex([...order]..removeAt(4)), 4);
      },
    );

    test('duplicate answered IDs are counted once', () {
      final p = plan();
      final order = p.itemOrder;
      expect(p.firstUnansweredIndex([order[0], order[0], order[0]]), 1);
    });

    test('all items answered: null, in any order', () {
      final p = plan();
      expect(p.firstUnansweredIndex(p.itemOrder), isNull);
      expect(p.firstUnansweredIndex(p.itemOrder.reversed), isNull);
    });

    test('an answered ID that is not in the plan is an error, not ignored', () {
      final p = plan(band: 'B1');
      expect(
        () => p.firstUnansweredIndex(['A2-01']),
        throwsInstrumentError('not in this plan'),
      );
      expect(
        () => p.firstUnansweredIndex([...p.itemOrder, 'unknown']),
        throwsInstrumentError('not in this plan'),
      );
    });
  });
}
