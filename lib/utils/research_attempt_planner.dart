import 'dart:math';

import '../models/research_attempt_plan.dart';
import '../models/research_instrument.dart';
import '../models/research_participant.dart';

/// Plans a fresh pretest or posttest attempt (`CLAUDE.md` §10,
/// `DATA_MODEL.md` §6b): the assigned band's 20 items in shuffled order,
/// each with its four substantive options shuffled. "Saya tidak tahu kata
/// ini" is never shuffled; [PlannedResearchItem.displayOptions] always
/// shows it last.
///
/// [random] is injected (same convention as `shuffleClozeOptions` and
/// `cowriteFallbackRandom`) so tests can use a seeded [Random]. The app
/// should pass `Random.secure()`. Pretest and posttest are planned
/// independently, each with its own call. The same seed always gives the
/// same plan; different seeds are not guaranteed to differ.
///
/// The result is validated through [ResearchAttemptPlan.fromOrder], so a
/// wrong band or instrument version throws [ResearchInstrumentException].
ResearchAttemptPlan planResearchAttempt({
  required ResearchInstrument instrument,
  required ResearchParticipantAssignment assignment,
  required Random random,
}) {
  final bandItems = instrument.itemsForBand(assignment.band);
  final itemOrder = [for (final item in bandItems) item.id]..shuffle(random);
  final optionsByItem = {
    for (final item in bandItems)
      item.id: [for (final option in item.options) option.id],
  };
  final optionOrder = {
    for (final itemId in itemOrder)
      itemId: optionsByItem[itemId]!..shuffle(random),
  };
  return ResearchAttemptPlan.fromOrder(
    instrument: instrument,
    assignment: assignment,
    itemOrder: itemOrder,
    optionOrder: optionOrder,
  );
}
