import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/research_treatment.dart';
import '../models/target_word_set.dart';
import '../models/vocab_bundle_entry.dart';
import '../services/research_treatment_service.dart';
import 'dashboard_providers.dart';
import 'history_providers.dart';

part 'research_treatment_providers.g.dart';

@riverpod
ResearchTreatmentService researchTreatmentService(Ref ref) => ResearchTreatmentService();

/// An official research session currently open for the student
/// (`DATA_MODEL.md` §6e) and whether it is already recorded as completed.
class ResearchSessionOffer {
  const ResearchSessionOffer({required this.set, required this.info, required this.completed});

  final TargetWordSet set;
  final TreatmentSetInfo info;

  /// This session number is already recorded for the student.
  final bool completed;

  ResearchSessionRef get ref =>
      ResearchSessionRef(setId: set.id, session: info.session, kind: info.kind, planVersion: info.planVersion);
}

/// Official research sessions open for [studentId] right now (the
/// researcher opened them in class and marked the student present). Live:
/// the same active-target query as a listener, so a session opened while
/// the dashboard is already showing appears by itself. The rules decide
/// whether a session can actually be started.
@riverpod
Stream<List<ResearchSessionOffer>> researchSessionOffers(Ref ref, String studentId) {
  final treatment = ref.watch(researchTreatmentServiceProvider);
  return ref.watch(targetWordSetServiceProvider).watchActiveForStudent(studentId).asyncMap((all) async {
    final sets = [
      for (final set in all)
        if (set.isResearch && set.targetStudentIds.contains(studentId)) set,
    ];
    if (sets.isEmpty) return const <ResearchSessionOffer>[];
    final record = await treatment.fetchRecord(studentId);
    return [
      for (final set in sets)
        ResearchSessionOffer(set: set, info: set.research!, completed: record.done.contains(set.research!.session)),
    ]..sort((a, b) => a.info.session.compareTo(b.info.session));
  });
}

/// The five words of an official session, resolved for display.
@riverpod
Future<List<VocabBundleEntry>> researchSessionEntries(Ref ref, String studentId, String setId) async {
  final offers = await ref.watch(researchSessionOffersProvider(studentId).future);
  final offer = offers.where((o) => o.set.id == setId).firstOrNull;
  if (offer == null) return const [];
  return resolveTargetWords(ref, [offer.set]);
}

/// Records any completed official session the app could not record when it
/// ended (best effort; runs when the dashboard opens). Never throws.
@riverpod
Future<int> researchTreatmentReconcile(Ref ref, String studentId) async {
  try {
    final service = ref.watch(researchTreatmentServiceProvider);
    if (!await service.isParticipant(studentId)) return 0;
    final sessions = await ref.watch(learningSessionServiceProvider).fetchForStudent(studentId);
    return await service.reconcile(uid: studentId, sessions: sessions);
  } catch (error) {
    debugPrint('researchTreatmentReconcile failed: $error');
    return 0;
  }
}
