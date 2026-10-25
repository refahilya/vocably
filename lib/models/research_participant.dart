/// The part of a participant's trusted `researchParticipants/{uid}` record
/// (`DATA_MODEL.md` §6b) that attempt planning needs: which band and which
/// instrument version the researcher assigned. Never derived from
/// `users.cefrLevel`.
///
/// Reading the record from Firestore (and its other fields, such as
/// `authorizedAttempts`) comes with the assessment service in a later
/// milestone; this step only plans attempts from an assignment.
class ResearchParticipantAssignment {
  const ResearchParticipantAssignment({
    required this.band,
    required this.instrumentVersion,
  });

  final String band;
  final String instrumentVersion;
}
