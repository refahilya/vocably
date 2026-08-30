import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/learning_progress.dart';
import 'package:vocably/utils/mastery_rules.dart';

void main() {
  group('initialMasteryStatus', () {
    test('always difficult — a word is never created already mastered', () {
      expect(initialMasteryStatus(), MasteryStatus.difficult);
    });
  });

  group('upgradedMasteryStatus', () {
    test(
      'upgrades difficult -> mastered when correct in cloze AND used independently',
      () {
        final result = upgradedMasteryStatus(
          currentMasteryStatus: MasteryStatus.difficult,
          correctInCloze: true,
          usedIndependentlyInCowrite: true,
        );
        expect(result, MasteryStatus.mastered);
      },
    );

    test('stays difficult when correct in cloze but NOT used independently (suggestion used)', () {
      final result = upgradedMasteryStatus(
        currentMasteryStatus: MasteryStatus.difficult,
        correctInCloze: true,
        usedIndependentlyInCowrite: false,
      );
      expect(result, MasteryStatus.difficult);
    });

    test('stays difficult when used independently but wrong in cloze', () {
      final result = upgradedMasteryStatus(
        currentMasteryStatus: MasteryStatus.difficult,
        correctInCloze: false,
        usedIndependentlyInCowrite: true,
      );
      expect(result, MasteryStatus.difficult);
    });

    test('stays difficult when both wrong in cloze and not used independently', () {
      final result = upgradedMasteryStatus(
        currentMasteryStatus: MasteryStatus.difficult,
        correctInCloze: false,
        usedIndependentlyInCowrite: false,
      );
      expect(result, MasteryStatus.difficult);
    });

    test('mastered never downgrades, even when this session got everything wrong', () {
      final result = upgradedMasteryStatus(
        currentMasteryStatus: MasteryStatus.mastered,
        correctInCloze: false,
        usedIndependentlyInCowrite: false,
      );
      expect(result, MasteryStatus.mastered);
    });

    test('mastered stays mastered even when this session would have qualified again', () {
      final result = upgradedMasteryStatus(
        currentMasteryStatus: MasteryStatus.mastered,
        correctInCloze: true,
        usedIndependentlyInCowrite: true,
      );
      expect(result, MasteryStatus.mastered);
    });
  });
}
