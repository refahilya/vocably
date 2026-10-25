import 'research_instrument.dart';
import 'research_participant.dart';

/// One item as the student sees it in an attempt: the word and its four
/// substantive options in this attempt's shuffled order. The bank's source
/// option order is deliberately not exposed here.
class PlannedResearchItem {
  const PlannedResearchItem._({
    required this.itemId,
    required this.word,
    required this.pos,
    required this.posLabel,
    required this.substantiveOptions,
    required this.dontKnowOption,
  });

  final String itemId;
  final String word;
  final String pos;
  final String posLabel;

  /// The four meaning options, in this attempt's shuffled order.
  final List<ResearchOption> substantiveOptions;

  /// "Saya tidak tahu kata ini" — kept separate from [substantiveOptions].
  final ResearchOption dontKnowOption;

  /// What the screen shows, top to bottom: the four shuffled options, then
  /// "Saya tidak tahu kata ini", which is always last.
  List<ResearchOption> get displayOptions => [
    ...substantiveOptions,
    dontKnowOption,
  ];
}

/// The item order and per-item option order of one pretest or posttest
/// attempt (`DATA_MODEL.md` §6b `itemOrder`/`optionOrder`). Holds no
/// correctness information and no scores.
///
/// Built either by `planResearchAttempt` (a fresh shuffle) or by
/// [ResearchAttemptPlan.fromOrder] (restoring a stored attempt's order).
/// Both go through the same validation.
class ResearchAttemptPlan {
  const ResearchAttemptPlan._({
    required this.band,
    required this.instrumentVersion,
    required this.items,
  });

  final String band;
  final String instrumentVersion;

  /// Exactly the band's 20 items, each once, in this attempt's order.
  final List<PlannedResearchItem> items;

  /// Validates [itemOrder] and [optionOrder] against the [assignment]'s band
  /// of [instrument], then builds the plan. Throws
  /// [ResearchInstrumentException] unless [itemOrder] lists every item of
  /// the band exactly once and [optionOrder] lists, for each of those items
  /// and no others, its four substantive options exactly once.
  factory ResearchAttemptPlan.fromOrder({
    required ResearchInstrument instrument,
    required ResearchParticipantAssignment assignment,
    required List<String> itemOrder,
    required Map<String, List<String>> optionOrder,
  }) {
    if (assignment.instrumentVersion != instrument.instrumentVersion) {
      throw ResearchInstrumentException(
        'assignment is for instrument "${assignment.instrumentVersion}", '
        'not "${instrument.instrumentVersion}"',
      );
    }
    final bandItems = {
      for (final item in instrument.itemsForBand(assignment.band))
        item.id: item,
    };

    if (itemOrder.length != bandItems.length ||
        itemOrder.toSet().length != itemOrder.length ||
        !itemOrder.every(bandItems.containsKey)) {
      throw ResearchInstrumentException(
        'item order must list each ${assignment.band} item exactly once',
      );
    }
    if (optionOrder.length != itemOrder.length ||
        !optionOrder.keys.every(bandItems.containsKey)) {
      throw const ResearchInstrumentException(
        'option order must have exactly one entry per planned item',
      );
    }

    final planned = <PlannedResearchItem>[];
    for (final itemId in itemOrder) {
      final item = bandItems[itemId]!;
      final optionsById = {
        for (final option in item.options) option.id: option,
      };
      final order = optionOrder[itemId]!;
      if (order.length != optionsById.length ||
          order.toSet().length != order.length ||
          !order.every(optionsById.containsKey)) {
        throw ResearchInstrumentException(
          'option order for $itemId must list its options exactly once',
        );
      }
      planned.add(
        PlannedResearchItem._(
          itemId: item.id,
          word: item.word,
          pos: item.pos,
          posLabel: item.posLabel,
          substantiveOptions: List.unmodifiable([
            for (final id in order) optionsById[id]!,
          ]),
          dontKnowOption: instrument.dontKnowOption,
        ),
      );
    }

    return ResearchAttemptPlan._(
      band: assignment.band,
      instrumentVersion: instrument.instrumentVersion,
      items: List.unmodifiable(planned),
    );
  }

  /// Item IDs in attempt order — the stored `itemOrder`.
  List<String> get itemOrder => [for (final item in items) item.itemId];

  /// Substantive option IDs per item, in display order — the stored
  /// `optionOrder`. "Tidak tahu" is not included; it is always last.
  Map<String, List<String>> get optionOrder => {
    for (final item in items)
      item.itemId: [for (final option in item.substantiveOptions) option.id],
  };

  /// Where to resume: the index (into [items]) of the first item, in this
  /// plan's order, whose ID is not in [answeredItemIds]. Answers may have
  /// been saved in any order, so this is not simply the answer count.
  ///
  /// Returns `null` when every item has been answered (the attempt is ready
  /// to complete). Throws [ResearchInstrumentException] if an answered ID is
  /// not in this plan: saved answers that don't belong to the plan mean the
  /// attempt and plan don't match, and resuming would be unsafe.
  int? firstUnansweredIndex(Iterable<String> answeredItemIds) {
    final answered = answeredItemIds.toSet();
    final planned = itemOrder.toSet();
    final unknown = answered.difference(planned);
    if (unknown.isNotEmpty) {
      throw ResearchInstrumentException(
        'answered item(s) not in this plan: ${unknown.join(', ')}',
      );
    }
    for (var i = 0; i < items.length; i++) {
      if (!answered.contains(items[i].itemId)) return i;
    }
    return null;
  }
}
