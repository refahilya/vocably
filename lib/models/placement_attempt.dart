import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'placement_instrument.dart';

/// `placementAttempts.context`: an official research attempt or an ordinary
/// learning-only attempt (`DATA_MODEL.md` §6). Learning attempts never
/// touch research records.
enum PlacementContext {
  research,
  learning;

  static PlacementContext? tryParse(Object? value) => switch (value) {
    'research' => research,
    'learning' => learning,
    _ => null,
  };
}

enum PlacementAttemptStatus {
  inProgress('in_progress'),
  submitted('submitted'),
  scored('scored'),
  voided('voided');

  const PlacementAttemptStatus(this.value);
  final String value;

  static PlacementAttemptStatus? tryParse(Object? value) {
    for (final status in values) {
      if (status.value == value) return status;
    }
    return null;
  }
}

/// The result the rules accept for a scored attempt: the level shown to the
/// student (A1* = A1 with [belowA1Threshold]) and the research target band
/// (`null` for C1). Band scores are never stored.
class PlacementResult {
  const PlacementResult({
    required this.resultLevel,
    required this.belowA1Threshold,
    required this.pretestTargetBand,
  });

  final String resultLevel;
  final bool belowA1Threshold;
  final String? pretestTargetBand;

  /// The six possible results, in the order the client proposes them to
  /// the rules (which recompute the K2 decision from the frozen answers and
  /// accept only the exact one). The app never learns more than the level.
  static const List<PlacementResult> candidates = [
    PlacementResult(resultLevel: 'A1', belowA1Threshold: true, pretestTargetBand: 'A2'),
    PlacementResult(resultLevel: 'A1', belowA1Threshold: false, pretestTargetBand: 'A2'),
    PlacementResult(resultLevel: 'A2', belowA1Threshold: false, pretestTargetBand: 'B1'),
    PlacementResult(resultLevel: 'B1', belowA1Threshold: false, pretestTargetBand: 'B2'),
    PlacementResult(resultLevel: 'B2', belowA1Threshold: false, pretestTargetBand: 'C1'),
    PlacementResult(resultLevel: 'C1', belowA1Threshold: false, pretestTargetBand: null),
  ];

  @override
  bool operator ==(Object other) =>
      other is PlacementResult &&
      other.resultLevel == resultLevel &&
      other.belowA1Threshold == belowA1Threshold &&
      other.pretestTargetBand == pretestTargetBand;

  @override
  int get hashCode => Object.hash(resultLevel, belowA1Threshold, pretestTargetBand);
}

/// One stored `placementAttempts/{uid}_{context}_{n}` document.
class PlacementAttemptRecord {
  const PlacementAttemptRecord({
    required this.id,
    required this.studentId,
    required this.context,
    required this.attemptNumber,
    required this.instrumentVersion,
    required this.itemOrder,
    required this.answers,
    required this.status,
    this.tabSwitchCount = 0,
    this.result,
    this.scoredAt,
    this.voidCategory,
  });

  final String id;
  final String studentId;
  final PlacementContext context;
  final int attemptNumber;
  final String instrumentVersion;
  final List<String> itemOrder;

  /// itemId → 'A'..'E'.
  final Map<String, String> answers;
  final PlacementAttemptStatus status;

  /// "App hidden" signals recorded while answering. Recorded only.
  final int tabSwitchCount;
  final PlacementResult? result;
  final DateTime? scoredAt;

  /// `technical` or `integrity` when voided by the researcher. The app only
  /// distinguishes "a new attempt may follow" from "contact the researcher".
  final String? voidCategory;

  static String idFor(String uid, PlacementContext context, int n) => '${uid}_${context.name}_$n';

  /// Index of the first unanswered item in display order, or `null`.
  int? get firstUnansweredIndex {
    for (var i = 0; i < itemOrder.length; i++) {
      if (!answers.containsKey(itemOrder[i])) return i;
    }
    return null;
  }

  bool get allAnswered => answers.length == kPlacementItemCount && firstUnansweredIndex == null;

  /// Strict parse; data the rules could never accept throws.
  factory PlacementAttemptRecord.fromFirestore(String id, Map<String, dynamic> data) {
    final context = PlacementContext.tryParse(data['context']);
    final status = PlacementAttemptStatus.tryParse(data['status']);
    final order = data['itemOrder'];
    final rawAnswers = data['answers'];
    if (context == null ||
        status == null ||
        data['studentId'] is! String ||
        data['attemptNumber'] is! int ||
        data['instrumentVersion'] is! String ||
        order is! List ||
        order.length != kPlacementItemCount ||
        order.any((e) => e is! String) ||
        rawAnswers is! Map) {
      throw const PlacementInstrumentException('stored attempt does not match the data model');
    }
    final answers = <String, String>{};
    for (final entry in rawAnswers.entries) {
      if (entry.key is! String || !kPlacementAnswerIds.contains(entry.value)) {
        throw const PlacementInstrumentException('stored answer is invalid');
      }
      answers[entry.key as String] = entry.value as String;
    }
    PlacementResult? result;
    if (status == PlacementAttemptStatus.scored ||
        (status == PlacementAttemptStatus.voided && data['resultLevel'] != null)) {
      final level = data['resultLevel'];
      final below = data['belowA1Threshold'];
      if (level is! String || !kPlacementBands.contains(level) || below is! bool) {
        throw const PlacementInstrumentException('stored result is invalid');
      }
      result = PlacementResult(
        resultLevel: level,
        belowA1Threshold: below,
        pretestTargetBand: data['pretestTargetBand'] as String?,
      );
    }
    final scoredAt = data['scoredAt'];
    return PlacementAttemptRecord(
      id: id,
      studentId: data['studentId'] as String,
      context: context,
      attemptNumber: data['attemptNumber'] as int,
      instrumentVersion: data['instrumentVersion'] as String,
      itemOrder: [for (final e in order) e as String],
      answers: answers,
      status: status,
      tabSwitchCount: data['tabSwitchCount'] is int ? data['tabSwitchCount'] as int : 0,
      result: result,
      scoredAt: scoredAt is Timestamp ? scoredAt.toDate() : null,
      voidCategory: data['voidCategory'] as String?,
    );
  }

  PlacementAttemptRecord copyWith({
    Map<String, String>? answers,
    PlacementAttemptStatus? status,
    int? tabSwitchCount,
  }) =>
      PlacementAttemptRecord(
        id: id,
        studentId: studentId,
        context: context,
        attemptNumber: attemptNumber,
        instrumentVersion: instrumentVersion,
        itemOrder: itemOrder,
        answers: answers ?? this.answers,
        status: status ?? this.status,
        tabSwitchCount: tabSwitchCount ?? this.tabSwitchCount,
        result: result,
        scoredAt: scoredAt,
        voidCategory: voidCategory,
      );

  // --- Write payloads: each matches one branch of the placement rules. ---

  /// Band order fixed, items shuffled within each band (spec K3, §8.2).
  static List<String> buildItemOrder(PlacementInstrument instrument, Random random) => [
    for (final band in kPlacementBands) ...(instrument.itemsForBand(band).map((i) => i.id).toList()..shuffle(random)),
  ];

  static Map<String, Object?> newAttemptData({
    required String studentId,
    required PlacementContext context,
    required int attemptNumber,
    required List<String> itemOrder,
    required Object serverTimestamp,
  }) => {
    'studentId': studentId,
    'context': context.name,
    'attemptNumber': attemptNumber,
    'instrumentVersion': kPlacementInstrumentVersion,
    'itemOrder': itemOrder,
    'answers': <String, Object?>{},
    'lastAnsweredItemId': null,
    'tabSwitchCount': 0,
    'status': PlacementAttemptStatus.inProgress.value,
    'startedAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };

  /// Field paths and values for one answer (`answers.<itemId>`).
  static Map<Object, Object?> answerUpdateData({
    required String itemId,
    required String answer,
    required Object serverTimestamp,
  }) => {
    FieldPath(['answers', itemId]): answer,
    'lastAnsweredItemId': itemId,
    'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> tabSwitchData(int newCount, Object serverTimestamp) => {
    'tabSwitchCount': newCount,
    'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> submitData(Object serverTimestamp) => {
    'status': PlacementAttemptStatus.submitted.value,
    'submittedAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> scoreData(PlacementResult result, Object serverTimestamp) => {
    'status': PlacementAttemptStatus.scored.value,
    'resultLevel': result.resultLevel,
    'belowA1Threshold': result.belowA1Threshold,
    'pretestTargetBand': result.pretestTargetBand,
    'scoringPolicy': 'K2',
    'scoredAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> userResultData(PlacementResult result, String attemptId) => {
    'resultLevel': result.resultLevel,
    'resultAttemptId': attemptId,
    'placementTestCompleted': true,
  };

  /// The participant's automatic band (or C1 exclusion) from a research result.
  static Map<String, Object?> participantBandData(
    PlacementResult result,
    String attemptId,
    Object serverTimestamp,
  ) {
    final band = result.pretestTargetBand;
    return {
      'band': band,
      'bandSource': band == null ? null : 'placement_test',
      'status': band == null ? 'excluded' : 'enrolled',
      'exclusionReason': band == null ? 'placement_c1' : null,
      'placementAttemptId': attemptId,
      'updatedAt': serverTimestamp,
    };
  }
}
