import 'package:cloud_firestore/cloud_firestore.dart';

/// Stages with their own researcher-controlled window in
/// `researchStudy/current.stages` (`DATA_MODEL.md` §6b).
abstract final class ResearchStageIds {
  static const placement = 'placement';
  static const preTest = 'preTest';
  static const postTest = 'postTest';
}

enum ResearchStudyStatus { setup, active, closed }

/// The trusted study lifecycle document `researchStudy/current`, written
/// only by researcher tooling. The security rules enforce the windows with
/// the server's clock; the app uses this copy only to explain why a stage
/// is not available, never to grant anything.
class ResearchStudy {
  const ResearchStudy({required this.status, required this.windows});

  final ResearchStudyStatus status;

  /// Stage id → `(openAt, closeAt)`; a missing stage was never opened.
  final Map<String, ({DateTime openAt, DateTime closeAt})> windows;

  /// Best-effort view of "the stage is open now" from the device clock.
  bool stageOpen(String stage, DateTime now) {
    final window = windows[stage];
    return status == ResearchStudyStatus.active &&
        window != null &&
        !now.isBefore(window.openAt) &&
        now.isBefore(window.closeAt);
  }

  /// Unknown or malformed data reads as a closed study (fail closed).
  factory ResearchStudy.fromFirestore(Map<String, dynamic>? data) {
    final status = switch (data?['status']) {
      'setup' => ResearchStudyStatus.setup,
      'active' => ResearchStudyStatus.active,
      _ => ResearchStudyStatus.closed,
    };
    final windows = <String, ({DateTime openAt, DateTime closeAt})>{};
    final stages = data?['stages'];
    if (stages is Map) {
      for (final entry in stages.entries) {
        final w = entry.value;
        if (w is Map && w['openAt'] is Timestamp && w['closeAt'] is Timestamp) {
          windows[entry.key as String] = (
            openAt: (w['openAt'] as Timestamp).toDate(),
            closeAt: (w['closeAt'] as Timestamp).toDate(),
          );
        }
      }
    }
    return ResearchStudy(status: status, windows: windows);
  }
}
