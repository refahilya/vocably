import 'research_attempt.dart';
import 'research_instrument.dart';

/// The part of a participant's trusted `researchParticipants/{uid}` record
/// (`DATA_MODEL.md` §6b) that attempt planning needs: which band and which
/// instrument version apply. Never derived from `users.cefrLevel` or
/// `users.resultLevel`.
class ResearchParticipantAssignment {
  const ResearchParticipantAssignment({
    required this.band,
    required this.instrumentVersion,
  });

  final String band;
  final String instrumentVersion;
}

/// `researchParticipants.status` (`DATA_MODEL.md` §6b). Records written by
/// the original enrolment tooling have no `status` and a researcher-assigned
/// band; they count as [enrolled].
enum ResearchParticipantStatus {
  /// Enrolled without a band; the research Placement Test assigns it.
  awaitingPlacement,

  /// Has a research band and may be authorized for pretest/posttest.
  enrolled,

  /// Not part of the research cohort (e.g. Placement result C1). May still
  /// use ordinary learning features, including a learning-only placement.
  excluded,

  /// The research placement attempt was voided after a confirmed human
  /// review; the researcher decides the band manually.
  awaitingManualBand,

  /// Manually banded; research stages stay blocked until the
  /// conditional-inclusion criteria are decided.
  conditional,
}

const _statusByName = {
  'awaiting_placement': ResearchParticipantStatus.awaitingPlacement,
  'enrolled': ResearchParticipantStatus.enrolled,
  'excluded': ResearchParticipantStatus.excluded,
  'awaiting_manual_band': ResearchParticipantStatus.awaitingManualBand,
  'conditional': ResearchParticipantStatus.conditional,
};

const _researchBands = ['A2', 'B1', 'B2', 'C1'];
const _reviewStatuses = ['pending', 'confirmed', 'not_confirmed'];

/// The signed-in student's own `researchParticipants/{uid}` document,
/// written only by researcher tooling — except the automatic placement band,
/// which the rules recompute (`DATA_MODEL.md` §6b). The app reads just what
/// it needs to decide what the student may do. `researchId`, `cohort`,
/// review reasons and timestamps are not needed by the app and are not
/// modelled.
class ResearchParticipant {
  const ResearchParticipant({
    required this.status,
    required this.assignment,
    required this.instrumentVersion,
    required this.authorizedPlacement,
    required this.authorizedPreTest,
    required this.authorizedPostTest,
    this.reviewPending = false,
  });

  final ResearchParticipantStatus status;

  /// `null` while the participant has no research band.
  final ResearchParticipantAssignment? assignment;

  /// Pretest/posttest instrument version (`v1`).
  final String instrumentVersion;
  final int authorizedPlacement;
  final int authorizedPreTest;
  final int authorizedPostTest;

  /// A human review is open; research actions wait for its outcome. The app
  /// shows only a neutral message — never the reason or any signal.
  final bool reviewPending;

  /// Band, `enrolled` and no pending review: pretest/posttest may proceed
  /// once the researcher authorizes them and the stage window is open.
  bool get canTakeResearchStages =>
      status == ResearchParticipantStatus.enrolled &&
      assignment != null &&
      !reviewPending;

  int authorizedAttempt(ResearchStage stage) => switch (stage) {
    ResearchStage.preTest => authorizedPreTest,
    ResearchStage.postTest => authorizedPostTest,
  };

  /// Strict parse: a record the researcher tooling would never write
  /// (unknown status, a band where none may exist, non-integer
  /// authorization, …) throws [ResearchInstrumentException] instead of
  /// being guessed at. A missing band is valid only for statuses that have
  /// none.
  factory ResearchParticipant.fromFirestore(Map<String, dynamic> data) {
    final rawStatus = data['status'];
    final status = rawStatus == null
        ? ResearchParticipantStatus.enrolled
        : _statusByName[rawStatus];
    if (status == null) {
      throw const ResearchInstrumentException('participant: unknown status');
    }
    final band = data['band'];
    final version = data['instrumentVersion'];
    final attempts = data['authorizedAttempts'];
    final needsBand =
        status == ResearchParticipantStatus.enrolled ||
        status == ResearchParticipantStatus.conditional;
    if (needsBand && (band is! String || !_researchBands.contains(band))) {
      throw const ResearchInstrumentException('participant: missing band');
    }
    if (!needsBand && band != null) {
      throw const ResearchInstrumentException(
        'participant: unexpected band for this status',
      );
    }
    if (version is! String || version.isEmpty) {
      throw const ResearchInstrumentException(
        'participant: missing instrumentVersion',
      );
    }
    if (attempts is! Map) {
      throw const ResearchInstrumentException(
        'participant: missing authorizedAttempts',
      );
    }
    final review = data['reviewStatus'];
    if (review != null && !_reviewStatuses.contains(review)) {
      throw const ResearchInstrumentException(
        'participant: unknown reviewStatus',
      );
    }
    int count(String stage, {bool optional = false}) {
      final value = attempts[stage];
      if (optional && value == null) return 0;
      if (value is! int || value < 0) {
        throw ResearchInstrumentException(
          'participant: authorizedAttempts.$stage must be a non-negative integer',
        );
      }
      return value;
    }

    return ResearchParticipant(
      status: status,
      assignment: needsBand
          ? ResearchParticipantAssignment(
              band: band as String,
              instrumentVersion: version,
            )
          : null,
      instrumentVersion: version,
      authorizedPlacement: count('placement', optional: true),
      authorizedPreTest: count('preTest'),
      authorizedPostTest: count('postTest'),
      reviewPending: review == 'pending',
    );
  }
}
