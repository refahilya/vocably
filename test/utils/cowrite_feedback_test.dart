import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/learning_session.dart';
import 'package:vocably/utils/cowrite_feedback.dart';

void main() {
  group('classifyCowriteFeedback', () {
    CowriteFeedbackKind classify({
      bool indonesian = false,
      Set<String> credited = const {},
      bool attempted = false,
      bool hasError = false,
    }) {
      return classifyCowriteFeedback(
        studentTurnContainsIndonesian: indonesian,
        creditedWords: credited,
        attemptedTargetWord: attempted,
        hasError: hasError,
      );
    }

    test('validated credit without an important problem is positive', () {
      expect(classify(credited: {'run'}, attempted: true), CowriteFeedbackKind.positive);
    });

    test('validated credit with an important problem needs improvement', () {
      expect(
        classify(credited: {'run'}, attempted: true, hasError: true),
        CowriteFeedbackKind.needsImprovement,
      );
    });

    test('an attempted but uncredited target word needs improvement', () {
      expect(classify(attempted: true), CowriteFeedbackKind.needsImprovement);
      expect(classify(attempted: true, hasError: true), CowriteFeedbackKind.needsImprovement);
    });

    test('no target word is a neutral reminder, with or without an error', () {
      expect(classify(), CowriteFeedbackKind.reminder);
      expect(classify(hasError: true), CowriteFeedbackKind.reminder);
    });

    test('Indonesian/mixed input is always a neutral reminder, even with credit', () {
      expect(
        classify(indonesian: true, credited: {'attack'}, attempted: true),
        CowriteFeedbackKind.reminder,
      );
    });

    test('never positive without code-validated credit', () {
      for (final attempted in [true, false]) {
        for (final hasError in [true, false]) {
          expect(
            classify(attempted: attempted, hasError: hasError),
            isNot(CowriteFeedbackKind.positive),
          );
        }
      }
    });
  });

  group('reconcileCowriteFeedback', () {
    test('replaces feedback when claimed words were all rejected', () {
      expect(
        reconcileCowriteFeedback(
          workerFeedback: 'Bagus, "attack" dipakai dengan tepat.',
          claimedWords: const ['attack'],
          creditedWords: const {},
          studentTurnContainsIndonesian: false,
        ),
        kCowriteUncreditedClaimFeedback,
      );
    });

    test('keeps feedback when something was credited, or nothing was claimed', () {
      expect(
        reconcileCowriteFeedback(
          workerFeedback: 'Tepat.',
          claimedWords: const ['attack'],
          creditedWords: const {'attack'},
          studentTurnContainsIndonesian: false,
        ),
        'Tepat.',
      );
      expect(
        reconcileCowriteFeedback(
          workerFeedback: 'Coba pakai kata "attack".',
          claimedWords: const [' '],
          creditedWords: const {},
          studentTurnContainsIndonesian: false,
        ),
        'Coba pakai kata "attack".',
      );
    });

    test('never replaces the Indonesian reminder', () {
      expect(
        reconcileCowriteFeedback(
          workerFeedback: 'Coba tulis kalimatmu dalam bahasa Inggris, ya.',
          claimedWords: const ['attack'],
          creditedWords: const {},
          studentTurnContainsIndonesian: true,
        ),
        'Coba tulis kalimatmu dalam bahasa Inggris, ya.',
      );
    });

    test('the replacement text matches the Worker constant verbatim', () {
      // Parity with UNCREDITED_CLAIM_FEEDBACK in vocably-ai-worker.
      expect(
        kCowriteUncreditedClaimFeedback,
        'Belum ada kata target yang terhitung di kalimat ini. Coba pakai salah satu '
        'kata target yang belum terpakai dalam kalimat lengkap yang bermakna, ya.',
      );
    });
  });

  test('CowriteTurn.toMap never persists the display-only feedbackKind', () {
    const turn = CowriteTurn(
      sender: CowriteSender.siswa,
      text: 'I ran.',
      feedback: 'Tepat.',
      usedSuggestion: false,
      feedbackKind: CowriteFeedbackKind.positive,
    );
    expect(turn.toMap(), {
      'sender': 'siswa',
      'text': 'I ran.',
      'feedback': 'Tepat.',
      'usedSuggestion': false,
    });
    expect(CowriteTurn.fromMap(turn.toMap()).feedbackKind, isNull);
  });
}
