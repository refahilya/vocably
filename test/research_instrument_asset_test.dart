import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Milestone 1 of the research module: the pretest/posttest instrument
/// bank is declared in `pubspec.yaml` and bundled with the app, and is
/// app-safe — items and options only, never the answer key
/// (`tools/research/README.md`). The deeper checks (counts, option IDs,
/// part-of-speech composition, vocab lookup) live in
/// `tools/research/test/bankAsset.test.js`; this test guards the
/// Flutter side: the asset actually ships, and nothing key-like does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bankPath = 'assets/research/instrument_v1.json';
  final forbiddenField = RegExp(
    r'correct|answer|key|letter|score|isright|solution',
    caseSensitive: false,
  );

  List<String> forbiddenFields(Object? value, String trail) {
    if (value is List) {
      return [
        for (var i = 0; i < value.length; i++)
          ...forbiddenFields(value[i], '$trail[$i]'),
      ];
    }
    if (value is Map<String, dynamic>) {
      return [
        for (final entry in value.entries) ...[
          if (forbiddenField.hasMatch(entry.key)) '$trail.${entry.key}',
          ...forbiddenFields(entry.value, '$trail.${entry.key}'),
        ],
      ];
    }
    return const [];
  }

  test('the instrument bank is bundled and contains 80 items, 20 per band', () async {
    final bank = jsonDecode(await rootBundle.loadString(bankPath)) as Map<String, dynamic>;
    final items = (bank['items'] as List).cast<Map<String, dynamic>>();

    expect(bank['instrumentVersion'], 'v1');
    expect(items, hasLength(80));
    for (final band in ['A2', 'B1', 'B2', 'C1']) {
      expect(items.where((item) => item['band'] == band), hasLength(20), reason: band);
    }
    for (final item in items) {
      expect(item['options'] as List, hasLength(4), reason: item['id'] as String);
    }
    expect(bank['dontKnowOption'], {'id': 'dont_know', 'text': 'Saya tidak tahu kata ini'});
  });

  test('the bundled bank carries no answer-key or correctness fields', () async {
    final bank = jsonDecode(await rootBundle.loadString(bankPath));
    expect(forbiddenFields(bank, r'$'), isEmpty);
  });
}
