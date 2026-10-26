import 'research_attempt.dart';
import 'research_instrument.dart';

/// The part of a participant's trusted `researchParticipants/{uid}` record
/// (`DATA_MODEL.md` §6b) that attempt planning needs: which band and which
/// instrument version the researcher assigned. Never derived from
/// `users.cefrLevel`.
class ResearchParticipantAssignment {
  const ResearchParticipantAssignment({
    required this.band,
    required this.instrumentVersion,
  });

  final String band;
  final String instrumentVersion;
}

/// The signed-in student's own `researchParticipants/{uid}` document,
/// written only by researcher tooling (`DATA_MODEL.md` §6b). The app reads
/// just what it needs to decide what the student may do: the assignment
/// and which attempt number of each stage is currently authorized
/// (0 = not authorized). `researchId`, `cohort` and timestamps are not
/// needed by the app and are not modelled.
class ResearchParticipant {
  const ResearchParticipant({
    required this.assignment,
    required this.authorizedPreTest,
    required this.authorizedPostTest,
  });

  final ResearchParticipantAssignment assignment;
  final int authorizedPreTest;
  final int authorizedPostTest;

  int authorizedAttempt(ResearchStage stage) => switch (stage) {
    ResearchStage.preTest => authorizedPreTest,
    ResearchStage.postTest => authorizedPostTest,
  };

  /// Strict parse: a record the researcher tooling would never write
  /// (missing band, non-integer authorization, …) throws
  /// [ResearchInstrumentException] instead of being guessed at.
  factory ResearchParticipant.fromFirestore(Map<String, dynamic> data) {
    final band = data['band'];
    final version = data['instrumentVersion'];
    final attempts = data['authorizedAttempts'];
    if (band is! String || band.isEmpty) {
      throw const ResearchInstrumentException('participant: missing band');
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
    int count(String stage) {
      final value = attempts[stage];
      if (value is! int || value < 0) {
        throw ResearchInstrumentException(
          'participant: authorizedAttempts.$stage must be a non-negative integer',
        );
      }
      return value;
    }

    return ResearchParticipant(
      assignment: ResearchParticipantAssignment(
        band: band,
        instrumentVersion: version,
      ),
      authorizedPreTest: count('preTest'),
      authorizedPostTest: count('postTest'),
    );
  }
}
