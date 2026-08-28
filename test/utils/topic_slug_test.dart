import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/utils/topic_slug.dart';

void main() {
  group('topicSlug', () {
    // Same cases as tools/vocab_import/test/seedDecision.test.js's
    // topicSlug test — this Dart port must stay byte-for-byte identical
    // to that one (see topic_slug.dart's doc comment for why).
    test('produces a stable, filesystem/docId-safe slug', () {
      expect(topicSlug('Body And Health'), 'body_and_health');
      expect(topicSlug('  General  '), 'general');
      expect(topicSlug(topicSlug('Body And Health')), 'body_and_health');
    });

    test('collapses punctuation/symbols into a single underscore', () {
      expect(topicSlug('Food & Drink'), 'food_drink');
      expect(topicSlug('Travel/Tourism'), 'travel_tourism');
    });

    test('trims leading/trailing underscores left over from stripped symbols', () {
      expect(topicSlug('!!!Emotions!!!'), 'emotions');
    });

    test('is idempotent — slugging an already-slugged name is a no-op', () {
      final once = topicSlug('Daily Activities');
      expect(topicSlug(once), once);
    });

    test('lowercases mixed-case input', () {
      expect(topicSlug('PERJALANAN'), 'perjalanan');
    });
  });
}
