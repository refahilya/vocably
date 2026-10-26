import 'package:cloud_firestore/cloud_firestore.dart' show FieldPath;

import '../utils/research_constants.dart';
import 'research_attempt_plan.dart';
import 'research_instrument.dart';

/// Pretest or posttest (`DATA_MODEL.md` §6b `stage`).
enum ResearchStage {
  preTest,
  postTest;

  /// The stored `stage` value.
  String get id => name;

  static ResearchStage? tryParse(Object? value) {
    for (final stage in values) {
      if (stage.id == value) return stage;
    }
    return null;
  }
}

/// `researchAssessmentResults.status`. `voided` is set only by researcher
/// tooling; the app never writes it.
enum ResearchAttemptStatus {
  inProgress('in_progress'),
  completed('completed'),
  voided('voided');

  const ResearchAttemptStatus(this.id);

  final String id;

  static ResearchAttemptStatus? tryParse(Object? value) {
    for (final status in values) {
      if (status.id == value) return status;
    }
    return null;
  }
}

/// One saved answer (`responses[itemId]`): the chosen option's opaque ID,
/// its exact bank text, and the 1-based position it was displayed at
/// ("Saya tidak tahu kata ini" is always 5). Carries no correctness
/// information — the app never knows which option is right.
class ResearchResponse {
  const ResearchResponse({
    required this.optionId,
    required this.optionText,
    required this.displayPosition,
  });

  final String optionId;
  final String optionText;
  final int displayPosition;

  /// The answer for choosing [optionId] on [item], exactly as the research
  /// rules expect it: position = index in [PlannedResearchItem.displayOptions]
  /// + 1, text = the bank text. Throws if [optionId] isn't displayed for
  /// [item].
  factory ResearchResponse.forPlannedItem(
    PlannedResearchItem item,
    String optionId,
  ) {
    final options = item.displayOptions;
    for (var i = 0; i < options.length; i++) {
      if (options[i].id == optionId) {
        return ResearchResponse(
          optionId: optionId,
          optionText: options[i].text,
          displayPosition: i + 1,
        );
      }
    }
    throw ResearchInstrumentException(
      'option "$optionId" is not displayed for ${item.itemId}',
    );
  }

  factory ResearchResponse.fromFirestore(Object? raw, String context) {
    if (raw is! Map) {
      throw ResearchInstrumentException('$context: answer must be a map');
    }
    final optionId = raw['optionId'];
    final optionText = raw['optionText'];
    final position = raw['displayPosition'];
    if (optionId is! String || optionText is! String || position is! int) {
      throw ResearchInstrumentException('$context: malformed answer');
    }
    return ResearchResponse(
      optionId: optionId,
      optionText: optionText,
      displayPosition: position,
    );
  }

  /// True when this saved answer is exactly what choosing [optionId] on
  /// [item] would have written — i.e. consistent with the attempt's order.
  bool matches(PlannedResearchItem item) {
    try {
      final expected = ResearchResponse.forPlannedItem(item, optionId);
      return expected.optionText == optionText &&
          expected.displayPosition == displayPosition;
    } on ResearchInstrumentException {
      return false;
    }
  }

  /// The stored map. [serverTimestamp] is `FieldValue.serverTimestamp()` in
  /// the app (the rules require `answeredAt == request.time`); tests pass a
  /// marker so the payload can be compared and replayed.
  Map<String, Object?> toFirestore(Object serverTimestamp) => {
    'optionId': optionId,
    'optionText': optionText,
    'displayPosition': displayPosition,
    'answeredAt': serverTimestamp,
  };
}

/// A `researchAssessmentResults/{uid}_{stage}_{n}` document as read back
/// from Firestore. Parsing is strict: anything the rules would never let a
/// client write, or the researcher tooling would never add, is rejected as
/// invalid rather than repaired.
class ResearchAttemptRecord {
  const ResearchAttemptRecord({
    required this.attemptId,
    required this.studentId,
    required this.stage,
    required this.attemptNumber,
    required this.band,
    required this.instrumentVersion,
    required this.itemOrder,
    required this.optionOrder,
    required this.responses,
    required this.status,
  });

  final String attemptId;
  final String studentId;
  final ResearchStage stage;
  final int attemptNumber;
  final String band;
  final String instrumentVersion;
  final List<String> itemOrder;
  final Map<String, List<String>> optionOrder;
  final Map<String, ResearchResponse> responses;
  final ResearchAttemptStatus status;

  /// `{uid}_{stage}_{n}` — the only attempt ID the rules accept.
  static String idFor(String uid, ResearchStage stage, int attemptNumber) =>
      '${uid}_${stage.id}_$attemptNumber';

  static const _fields = {
    'studentId',
    'stage',
    'attemptNumber',
    'band',
    'instrumentVersion',
    'itemOrder',
    'optionOrder',
    'responses',
    'lastAnsweredItemId',
    'status',
    'startedAt',
    'updatedAt',
    'completedAt',
    // Researcher tooling only (voiding).
    'voidReason',
    'voidedAt',
  };

  factory ResearchAttemptRecord.fromFirestore(
    String attemptId,
    Map<String, dynamic> data,
  ) {
    final context = 'attempt $attemptId';
    final unknown = data.keys.where((key) => !_fields.contains(key));
    if (unknown.isNotEmpty) {
      throw ResearchInstrumentException(
        '$context: unexpected field(s) ${unknown.join(', ')}',
      );
    }
    final studentId = data['studentId'];
    final stage = ResearchStage.tryParse(data['stage']);
    final attemptNumber = data['attemptNumber'];
    final band = data['band'];
    final version = data['instrumentVersion'];
    final status = ResearchAttemptStatus.tryParse(data['status']);
    if (studentId is! String ||
        stage == null ||
        attemptNumber is! int ||
        attemptNumber < 1 ||
        band is! String ||
        version is! String ||
        status == null) {
      throw ResearchInstrumentException('$context: malformed metadata');
    }
    if (attemptId != idFor(studentId, stage, attemptNumber)) {
      throw ResearchInstrumentException(
        '$context: id does not match its owner, stage and number',
      );
    }

    final rawItems = data['itemOrder'];
    final rawOptions = data['optionOrder'];
    final rawResponses = data['responses'];
    if (rawItems is! List || rawItems.any((id) => id is! String)) {
      throw ResearchInstrumentException('$context: malformed itemOrder');
    }
    if (rawOptions is! Map ||
        rawOptions.entries.any(
          (e) =>
              e.key is! String ||
              e.value is! List ||
              (e.value as List).any((id) => id is! String),
        )) {
      throw ResearchInstrumentException('$context: malformed optionOrder');
    }
    if (rawResponses is! Map || rawResponses.keys.any((k) => k is! String)) {
      throw ResearchInstrumentException('$context: malformed responses');
    }

    return ResearchAttemptRecord(
      attemptId: attemptId,
      studentId: studentId,
      stage: stage,
      attemptNumber: attemptNumber,
      band: band,
      instrumentVersion: version,
      itemOrder: List.unmodifiable(rawItems.cast<String>()),
      optionOrder: Map.unmodifiable({
        for (final e in rawOptions.entries)
          e.key as String: List<String>.unmodifiable(
            (e.value as List).cast<String>(),
          ),
      }),
      responses: Map.unmodifiable({
        for (final e in rawResponses.entries)
          e.key as String: ResearchResponse.fromFirestore(
            e.value,
            '$context answer ${e.key}',
          ),
      }),
      status: status,
    );
  }

  /// The document a student creates to start an attempt: exactly the
  /// field list the research rules accept, with the order taken from
  /// [plan]. [serverTimestamp] as in [ResearchResponse.toFirestore].
  static Map<String, Object?> newAttemptData({
    required String studentId,
    required ResearchStage stage,
    required int attemptNumber,
    required ResearchAttemptPlan plan,
    required Object serverTimestamp,
  }) => {
    'studentId': studentId,
    'stage': stage.id,
    'attemptNumber': attemptNumber,
    'band': plan.band,
    'instrumentVersion': plan.instrumentVersion,
    'itemOrder': plan.itemOrder,
    'optionOrder': plan.optionOrder,
    'responses': <String, Object?>{},
    'lastAnsweredItemId': null,
    'status': ResearchAttemptStatus.inProgress.id,
    'startedAt': serverTimestamp,
    'updatedAt': serverTimestamp,
    'completedAt': null,
  };

  /// The update that saves one answer. Item IDs contain `-`, so the nested
  /// field is addressed with a [FieldPath], never a dotted string.
  static Map<Object, Object?> answerUpdateData({
    required String itemId,
    required ResearchResponse response,
    required Object serverTimestamp,
  }) => {
    FieldPath(['responses', itemId]): response.toFirestore(serverTimestamp),
    'lastAnsweredItemId': itemId,
    'updatedAt': serverTimestamp,
  };

  /// The update that marks the attempt completed.
  static Map<String, Object?> completionData(Object serverTimestamp) => {
    'status': ResearchAttemptStatus.completed.id,
    'completedAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };

  /// `true` once every item of the attempt has a saved answer.
  bool get allItemsAnswered =>
      responses.length == kResearchItemsPerBand &&
      itemOrder.every(responses.containsKey);
}
