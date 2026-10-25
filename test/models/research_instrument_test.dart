import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/models/research_instrument.dart';

/// A minimal valid bank with [bands] × 20 synthetic items. Option IDs are
/// made-up opaque hex; nothing here is real instrument content.
Map<String, dynamic> syntheticBank({List<String> bands = const ['A2', 'B1']}) {
  var counter = 0;
  String optionId() => 'opt_${(counter++).toRadixString(16).padLeft(12, '0')}';
  // Round-tripped through JSON so it has the same loose types as a decoded asset.
  return jsonDecode(
        jsonEncode({
          'schemaVersion': 1,
          'instrumentId': 'vocably-pretest-posttest',
          'instrumentVersion': 'v1',
          'status': 'synthetic',
          'source': {'title': 't', 'fileName': 'f', 'sha256': 's'},
          'bands': [...bands],
          'itemsPerBand': 20,
          'optionOrder': 'synthetic',
          'dontKnowOption': {
            'id': 'dont_know',
            'text': 'Saya tidak tahu kata ini',
          },
          'items': [
            for (final band in bands)
              for (var n = 1; n <= 20; n++)
                {
                  'id': '$band-${n.toString().padLeft(2, '0')}',
                  'band': band,
                  'number': n,
                  'word': 'word$band$n',
                  'pos': 'noun',
                  'posLabel': 'kata benda',
                  'options': [
                    for (var o = 0; o < 4; o++)
                      {'id': optionId(), 'text': 'Pilihan $band $n $o'},
                  ],
                },
          ],
        }),
      )
      as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ResearchInstrument parse(Object? json, {String version = 'v1'}) =>
      ResearchInstrument.fromJson(json, expectedVersion: version);

  Matcher throwsInstrumentError(String messagePart) => throwsA(
    isA<ResearchInstrumentException>().having(
      (e) => e.message,
      'message',
      contains(messagePart),
    ),
  );

  List<dynamic> itemsOf(Map<String, dynamic> bank) => bank['items'] as List;
  Map<String, dynamic> item0(Map<String, dynamic> bank) =>
      itemsOf(bank)[0] as Map<String, dynamic>;
  List<dynamic> options0(Map<String, dynamic> bank) =>
      item0(bank)['options'] as List;

  group('the bundled bank', () {
    test('parses, with 20 valid items for each of the four bands', () async {
      final json = jsonDecode(
        await rootBundle.loadString('assets/research/instrument_v1.json'),
      );
      final instrument = parse(json);

      expect(instrument.instrumentVersion, 'v1');
      expect(instrument.bands, ['A2', 'B1', 'B2', 'C1']);
      expect(instrument.items, hasLength(80));
      for (final band in instrument.bands) {
        final items = instrument.itemsForBand(band);
        expect(items, hasLength(20), reason: band);
        expect(items.every((item) => item.band == band), isTrue, reason: band);
        expect(
          items.map((item) => item.id).toSet(),
          hasLength(20),
          reason: band,
        );
        for (final item in items) {
          expect(item.options, hasLength(4), reason: item.id);
          expect(
            item.options.any((o) => o.id == 'dont_know'),
            isFalse,
            reason: item.id,
          );
        }
      }
      expect(instrument.dontKnowOption.id, 'dont_know');
      expect(instrument.dontKnowOption.text, 'Saya tidak tahu kata ini');
    });
  });

  group('ResearchInstrument.fromJson accepts', () {
    test('a valid synthetic bank', () {
      final instrument = parse(syntheticBank());
      expect(instrument.itemsForBand('A2'), hasLength(20));
      expect(instrument.itemsForBand('B1').first.id, 'B1-01');
    });
  });

  group('ResearchInstrument.fromJson rejects', () {
    test('a non-object document', () {
      expect(() => parse([]), throwsInstrumentError('expected a JSON object'));
      expect(
        () => parse(null),
        throwsInstrumentError('expected a JSON object'),
      );
    });

    test('an unsupported schemaVersion', () {
      expect(
        () => parse(syntheticBank()..['schemaVersion'] = 2),
        throwsInstrumentError('schemaVersion'),
      );
      expect(
        () => parse(syntheticBank()..remove('schemaVersion')),
        throwsInstrumentError('schemaVersion'),
      );
    });

    test('a different instrumentId', () {
      expect(
        () => parse(syntheticBank()..['instrumentId'] = 'other'),
        throwsInstrumentError('instrumentId'),
      );
    });

    test('a bank whose version is not the requested one', () {
      expect(
        () => parse(syntheticBank(), version: 'v2'),
        throwsInstrumentError('does not match'),
      );
      expect(
        () => parse(syntheticBank()..remove('instrumentVersion')),
        throwsInstrumentError('instrumentVersion'),
      );
    });

    test('an itemsPerBand other than 20', () {
      expect(
        () => parse(syntheticBank()..['itemsPerBand'] = 19),
        throwsInstrumentError('itemsPerBand'),
      );
    });

    test('missing, empty or duplicated bands', () {
      expect(
        () => parse(syntheticBank()..remove('bands')),
        throwsInstrumentError('"bands"'),
      );
      expect(
        () => parse(syntheticBank()..['bands'] = []),
        throwsInstrumentError('"bands"'),
      );
      expect(
        () => parse(syntheticBank()..['bands'] = ['A2', 'A2', 'B1']),
        throwsInstrumentError('"bands"'),
      );
    });

    test('a dontKnowOption that does not match the contract', () {
      expect(
        () => parse(
          syntheticBank()
            ..['dontKnowOption'] = {'id': 'dont_know', 'text': 'Tidak tahu'},
        ),
        throwsInstrumentError('dontKnowOption'),
      );
      expect(
        () => parse(syntheticBank()..remove('dontKnowOption')),
        throwsInstrumentError('dontKnowOption'),
      );
    });

    test('unknown fields at any level, so key-like data cannot slip in', () {
      expect(
        () => parse(syntheticBank()..['answerKey'] = {}),
        throwsInstrumentError('unexpected field'),
      );
      final itemExtra = syntheticBank();
      item0(itemExtra)['correctOptionId'] = 'x';
      expect(() => parse(itemExtra), throwsInstrumentError('unexpected field'));
      final optionExtra = syntheticBank();
      (options0(optionExtra)[0] as Map<String, dynamic>)['isCorrect'] = true;
      expect(
        () => parse(optionExtra),
        throwsInstrumentError('unexpected field'),
      );
    });

    for (final field in ['id', 'band', 'word', 'pos', 'posLabel']) {
      test('an item without "$field" or with it empty', () {
        final missing = syntheticBank();
        item0(missing).remove(field);
        expect(
          () => parse(missing),
          throwsA(isA<ResearchInstrumentException>()),
        );
        final empty = syntheticBank();
        item0(empty)[field] = '  ';
        expect(() => parse(empty), throwsA(isA<ResearchInstrumentException>()));
      });
    }

    test(
      'an item with a missing or invalid number, or an id that does not match it',
      () {
        final missing = syntheticBank();
        item0(missing).remove('number');
        expect(() => parse(missing), throwsInstrumentError('"number"'));
        final mismatch = syntheticBank();
        item0(mismatch)['number'] = 2;
        expect(
          () => parse(mismatch),
          throwsInstrumentError('does not match band and number'),
        );
      },
    );

    test('an item without exactly four options', () {
      final three = syntheticBank();
      options0(three).removeLast();
      expect(() => parse(three), throwsInstrumentError('exactly 4 options'));
      final none = syntheticBank();
      item0(none).remove('options');
      expect(() => parse(none), throwsInstrumentError('exactly 4 options'));
    });

    test('invalid options', () {
      final badId = syntheticBank();
      (options0(badId)[0] as Map<String, dynamic>)['id'] = 'dont_know';
      expect(() => parse(badId), throwsInstrumentError('invalid option id'));
      final noText = syntheticBank();
      (options0(noText)[0] as Map<String, dynamic>).remove('text');
      expect(() => parse(noText), throwsInstrumentError('"text"'));
      final notObject = syntheticBank();
      options0(notObject)[0] = 'Iklim';
      expect(
        () => parse(notObject),
        throwsInstrumentError('expected a JSON object'),
      );
    });

    test('duplicate option ids or texts within an item', () {
      final dupId = syntheticBank();
      (options0(dupId)[1] as Map<String, dynamic>)['id'] =
          (options0(dupId)[0] as Map)['id'];
      expect(() => parse(dupId), throwsInstrumentError('duplicate option id'));
      final dupText = syntheticBank();
      (options0(dupText)[1] as Map<String, dynamic>)['text'] =
          (options0(dupText)[0] as Map)['text'];
      expect(
        () => parse(dupText),
        throwsInstrumentError('duplicate option text'),
      );
    });

    test('duplicate item ids', () {
      final bank = syntheticBank();
      itemsOf(bank)[1] = Map<String, dynamic>.of(item0(bank));
      expect(() => parse(bank), throwsInstrumentError('duplicate item id'));
    });

    test('an item in an undeclared band', () {
      final bank = syntheticBank()..['bands'] = ['A2'];
      expect(() => parse(bank), throwsInstrumentError('undeclared band'));
    });

    test('a band without exactly 20 items', () {
      final short = syntheticBank();
      itemsOf(short).removeAt(0);
      expect(() => parse(short), throwsInstrumentError('band A2 has 19 items'));
      final empty = syntheticBank()..['bands'] = ['A2', 'B1', 'C1'];
      expect(() => parse(empty), throwsInstrumentError('band C1 has 0 items'));
    });
  });

  test('itemsForBand rejects a band the bank does not declare', () {
    final instrument = parse(syntheticBank());
    expect(
      () => instrument.itemsForBand('C2'),
      throwsInstrumentError('band "C2"'),
    );
  });
}
