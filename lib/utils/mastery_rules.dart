/// Pure implementation of `DATA_MODEL.md` §3 / `SPEC.md` §6's mastery
/// state machine — isolated from any Firestore/Riverpod dependency so
/// every rule (default `difficult`, upgrade condition, permanent
/// `mastered`) can be exhaustively unit-tested without a fake service.
///
/// The state machine is written to Firestore in **two separate writes**,
/// matching the project owner's Milestone 7 Decision 3 (`learningProgress`
/// is written immediately once the cloze test is submitted, not deferred
/// to the end of co-write — otherwise a session abandoned before Fase 3
/// would never record anything, contradicting `DATA_MODEL.md` §3 rule 1's
/// own stated purpose):
///
/// 1. **Cloze-submit time** (`LearningProgressService.recordClozeCompletion`)
///    — a word becomes `learnedStatus: sudahDipelajari` the first time it's
///    ever used in a session (regardless of whether the cloze answer was
///    correct — "learned" means "encountered in a session", `SPEC.md` §6).
///    [initialMasteryStatus] decides what `masteryStatus` a *brand-new*
///    progress doc gets at this moment.
/// 2. **Co-write-completion time** (`LearningProgressService.
///    recordCowriteCompletion`) — [upgradedMasteryStatus] decides whether
///    an existing doc's `masteryStatus` should become `mastered`.
library;

import '../models/learning_progress.dart';

/// What a *brand-new* `learningProgress` doc's `masteryStatus` should be,
/// the moment a word is learned for the very first time. Always
/// `difficult` — `DATA_MODEL.md` §3 rule 1: "Begitu `learnedStatus` jadi
/// `sudahDipelajari`, `masteryStatus` langsung diisi `difficult`." A word
/// is never upgraded straight to `mastered` on its very first cloze
/// submission alone — reaching `mastered` always requires the co-write
/// half of the same session too (rule 2), which hasn't happened yet at
/// this point in the flow.
String initialMasteryStatus() => MasteryStatus.difficult;

/// Decides [currentMasteryStatus]'s next value after a co-write phase
/// completes, per `DATA_MODEL.md` §3 rules 2–3:
///
/// - If [currentMasteryStatus] is already [MasteryStatus.mastered], it
///   **stays** `mastered` — permanent, never re-evaluated, never
///   downgraded, regardless of this session's results (rule 3).
/// - Otherwise, it becomes `mastered` only if **both** [correctInCloze]
///   and [usedIndependentlyInCowrite] are `true` (rule 2) — otherwise it
///   stays [MasteryStatus.difficult].
///
/// [currentMasteryStatus] should never be `null` when this is called —
/// `recordClozeCompletion` always creates the doc with a non-null
/// [initialMasteryStatus] first, and co-write completion only ever
/// follows a completed cloze submission for the same session's words.
String upgradedMasteryStatus({
  required String currentMasteryStatus,
  required bool correctInCloze,
  required bool usedIndependentlyInCowrite,
}) {
  if (currentMasteryStatus == MasteryStatus.mastered) {
    return MasteryStatus.mastered;
  }
  if (correctInCloze && usedIndependentlyInCowrite) {
    return MasteryStatus.mastered;
  }
  return MasteryStatus.difficult;
}
