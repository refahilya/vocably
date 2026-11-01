import 'placement_attempt.dart';
import 'placement_instrument.dart';
import 'research_participant.dart';
import 'research_study.dart';

/// `placementConfig/current`: which instrument version is live and whether
/// ordinary (learning-only) placement is open. Trusted-tooling only.
class PlacementConfig {
  const PlacementConfig({required this.instrumentVersion, required this.learningOpen});

  final String instrumentVersion;
  final bool learningOpen;
}

/// Why the student cannot take a placement attempt right now.
enum PlacementBlock {
  /// No `placementConfig`, or it names an instrument this app doesn't have.
  notConfigured,

  /// Research participant: the researcher hasn't opened the placement
  /// window (or it was closed, or the study isn't active).
  researchClosed,

  /// Research participant: no attempt number authorized yet.
  researchNotAuthorized,

  /// A human review is open; the student only sees a neutral message.
  reviewPending,

  /// The research attempt was voided for a technical reason; the
  /// researcher may authorize a new attempt.
  voidedTechnical,

  /// The research attempt was voided after a review, or the band is being
  /// decided by the researcher: no replacement attempt.
  contactResearcher,

  /// Ordinary (learning-only) placement is closed by the researcher.
  learningClosed,
}

/// What the Placement Test screen should offer (`SPEC.md` §3.1).
sealed class PlacementStatus {
  const PlacementStatus();
}

class PlacementBlocked extends PlacementStatus {
  const PlacementBlocked(this.reason, {this.lastResult});

  final PlacementBlock reason;

  /// The latest scored result, when one exists (shown alongside).
  final PlacementAttemptRecord? lastResult;
}

/// No attempt to resume: show the instructions and "Mulai".
class PlacementCanStart extends PlacementStatus {
  const PlacementCanStart(this.context, this.attemptNumber, {this.lastResult});

  final PlacementContext context;
  final int attemptNumber;
  final PlacementAttemptRecord? lastResult;
}

/// An unfinished attempt; [open] is false while its window is closed
/// (answers stay saved; the student waits for the supervisor).
class PlacementResumable extends PlacementStatus {
  const PlacementResumable(this.attempt, {required this.open});

  final PlacementAttemptRecord attempt;
  final bool open;
}

/// Submitted (answers frozen) but not scored yet: scoring is retried.
class PlacementAwaitingScore extends PlacementStatus {
  const PlacementAwaitingScore(this.attempt);

  final PlacementAttemptRecord attempt;
}

/// A scored result to show. [nextLearningAttempt] is set when a
/// learning-only retake is open now; [retakeAvailableAt] when one will be.
class PlacementHasResult extends PlacementStatus {
  const PlacementHasResult(
    this.attempt, {
    this.nextLearningAttempt,
    this.retakeAvailableAt,
  });

  final PlacementAttemptRecord attempt;
  final int? nextLearningAttempt;
  final DateTime? retakeAvailableAt;
}

/// Minimum time between learning attempts (mirrors `firestore.rules`).
const Duration kLearningRetakeInterval = Duration(days: 1);

/// Decides the screen's status from server data. Mirrors the placement
/// rules so the app offers only what the rules would accept; the rules
/// remain the authority (a refused write is always followed by a re-read).
PlacementStatus resolvePlacementStatus({
  required PlacementConfig? config,
  required ResearchParticipant? participant,
  required ResearchStudy study,
  required List<PlacementAttemptRecord> attempts,
  required DateTime now,
}) {
  if (config == null || config.instrumentVersion != kPlacementInstrumentVersion) {
    return const PlacementBlocked(PlacementBlock.notConfigured);
  }
  PlacementAttemptRecord? find(PlacementContext context, int n) {
    for (final a in attempts) {
      if (a.context == context && a.attemptNumber == n) return a;
    }
    return null;
  }

  final scored = [
    for (final a in attempts)
      if (a.status == PlacementAttemptStatus.scored && a.scoredAt != null) a,
  ]..sort((a, b) => a.scoredAt!.compareTo(b.scoredAt!));
  final lastResult = scored.isEmpty ? null : scored.last;

  // Research participant still awaiting the official placement.
  if (participant != null && participant.status == ResearchParticipantStatus.awaitingPlacement) {
    final n = participant.authorizedPlacement;
    if (n < 1) return const PlacementBlocked(PlacementBlock.researchNotAuthorized);
    final open = study.stageOpen(ResearchStageIds.placement, now);
    final attempt = find(PlacementContext.research, n);
    if (attempt == null) {
      if (participant.reviewPending) return const PlacementBlocked(PlacementBlock.reviewPending);
      return open
          ? PlacementCanStart(PlacementContext.research, n)
          : const PlacementBlocked(PlacementBlock.researchClosed);
    }
    return switch (attempt.status) {
      PlacementAttemptStatus.inProgress =>
        participant.reviewPending
            ? const PlacementBlocked(PlacementBlock.reviewPending)
            : PlacementResumable(attempt, open: open),
      PlacementAttemptStatus.submitted => PlacementAwaitingScore(attempt),
      PlacementAttemptStatus.scored => PlacementHasResult(attempt),
      PlacementAttemptStatus.voided =>
        attempt.voidCategory == 'technical'
            ? const PlacementBlocked(PlacementBlock.voidedTechnical)
            : const PlacementBlocked(PlacementBlock.contactResearcher),
    };
  }
  if (participant != null && participant.status == ResearchParticipantStatus.awaitingManualBand) {
    return PlacementBlocked(PlacementBlock.contactResearcher, lastResult: lastResult);
  }

  // A research attempt that is submitted but not yet scored is still scored
  // (also after closure, also when the participant is otherwise done).
  for (final a in attempts) {
    if (a.context == PlacementContext.research && a.status == PlacementAttemptStatus.submitted) {
      return PlacementAwaitingScore(a);
    }
  }

  // Ordinary learning placement: non-participants, excluded participants,
  // and everyone once the study is closed. Enrolled/conditional
  // participants keep their official result during the study.
  final learningAllowed = participant == null ||
      participant.status == ResearchParticipantStatus.excluded ||
      study.status == ResearchStudyStatus.closed;
  if (!learningAllowed) {
    return lastResult != null
        ? PlacementHasResult(lastResult)
        : const PlacementBlocked(PlacementBlock.contactResearcher);
  }

  final learning = [
    for (final a in attempts)
      if (a.context == PlacementContext.learning) a,
  ]..sort((a, b) => a.attemptNumber.compareTo(b.attemptNumber));
  final latest = learning.isEmpty ? null : learning.last;
  if (latest != null && latest.status == PlacementAttemptStatus.inProgress) {
    return PlacementResumable(latest, open: config.learningOpen);
  }
  if (latest != null && latest.status == PlacementAttemptStatus.submitted) {
    return PlacementAwaitingScore(latest);
  }
  final nextNumber = (latest?.attemptNumber ?? 0) + 1;
  final availableAt = latest?.status == PlacementAttemptStatus.scored && latest!.scoredAt != null
      ? latest.scoredAt!.add(kLearningRetakeInterval)
      : null;
  final waiting = availableAt != null && now.isBefore(availableAt);
  if (lastResult != null) {
    return PlacementHasResult(
      lastResult,
      nextLearningAttempt: config.learningOpen && !waiting ? nextNumber : null,
      retakeAvailableAt: config.learningOpen && waiting ? availableAt : null,
    );
  }
  return config.learningOpen
      ? PlacementCanStart(PlacementContext.learning, nextNumber)
      : const PlacementBlocked(PlacementBlock.learningClosed);
}
