import '../models/learning_session.dart';

/// Co-Write feedback presentation and reconciliation (CW-02, `SPEC.md`
/// §5.3). Feedback text comes from the model; everything here is decided
/// from the application's own, code-validated result for the turn.

/// Replacement feedback for a contradiction: the Worker claimed target-word
/// use (so its feedback likely praises it) but code validation credited
/// nothing. Kept verbatim in parity with the Worker's
/// `UNCREDITED_CLAIM_FEEDBACK` (`vocably-ai-worker/src/handlers/cowriteTurn.ts`),
/// which applies the same rule before responding.
const String kCowriteUncreditedClaimFeedback =
    'Belum ada kata target yang terhitung di kalimat ini. Coba pakai salah satu '
    'kata target yang belum terpakai dalam kalimat lengkap yang bermakna, ya.';

/// The feedback to attach to a student turn. Returns
/// [kCowriteUncreditedClaimFeedback] when [claimedWords] (the Worker's list)
/// is non-empty but [creditedWords] (the client's validation of it) is
/// empty, unless the turn is Indonesian/mixed-language, whose reminder is
/// kept. Otherwise returns [workerFeedback] unchanged.
///
/// A current Worker already applies this rule and only returns validated
/// words, so this mostly matters for an older deployed Worker that returns
/// unvalidated claims.
String? reconcileCowriteFeedback({
  required String? workerFeedback,
  required List<String> claimedWords,
  required Set<String> creditedWords,
  required bool studentTurnContainsIndonesian,
}) {
  final claimedAny = claimedWords.any((w) => w.trim().isNotEmpty);
  if (claimedAny && creditedWords.isEmpty && !studentTurnContainsIndonesian) {
    return kCowriteUncreditedClaimFeedback;
  }
  return workerFeedback;
}

/// Classifies a student turn's feedback for display. Inputs are all
/// application-side facts about that one turn:
///
/// - [studentTurnContainsIndonesian]: the app's `containsIndonesianWords`.
/// - [creditedWords]: target words code-validated for this turn.
/// - [attemptedTargetWord]: a remaining target word occurs in the text
///   (`containsAnyTargetWord`), credited or not.
/// - [hasError]: the Worker's "important problem" flag.
///
/// [CowriteFeedbackKind.positive] therefore requires code-validated credit;
/// positive-sounding text alone never produces it. The kind describes this
/// turn only and says nothing about mastery.
CowriteFeedbackKind classifyCowriteFeedback({
  required bool studentTurnContainsIndonesian,
  required Set<String> creditedWords,
  required bool attemptedTargetWord,
  required bool hasError,
}) {
  if (studentTurnContainsIndonesian) return CowriteFeedbackKind.reminder;
  if (creditedWords.isNotEmpty) {
    return hasError ? CowriteFeedbackKind.needsImprovement : CowriteFeedbackKind.positive;
  }
  if (attemptedTargetWord) return CowriteFeedbackKind.needsImprovement;
  return CowriteFeedbackKind.reminder;
}
