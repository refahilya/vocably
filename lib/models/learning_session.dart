import 'package:cloud_firestore/cloud_firestore.dart';

/// `learningSessions.sourceType` values (`DATA_MODEL.md` §4). All three
/// run the identical 3-phase flow — this only records where the target
/// words came from.
abstract final class LearningSessionSourceType {
  static const String keranjangPelajari = 'keranjangPelajari';
  static const String targetGuru = 'targetGuru';
  static const String pelajariUlangDifficult = 'pelajariUlangDifficult';
}

/// `learningSessions.currentPhase` values (`DATA_MODEL.md` §4).
abstract final class LearningSessionPhase {
  static const String membaca = 'membaca';
  static const String clozeTest = 'clozeTest';
  static const String coWrite = 'coWrite';
  static const String selesai = 'selesai';
}

/// One turn in `learningSessions.cowriteTranscript` (`DATA_MODEL.md` §4).
class CowriteTurn {
  const CowriteTurn({
    required this.sender,
    required this.text,
    required this.feedback,
    required this.usedSuggestion,
  });

  /// `"siswa"` or `"ai"`.
  final String sender;
  final String text;
  final String? feedback;
  final bool usedSuggestion;

  factory CowriteTurn.fromMap(Map<String, dynamic> data) {
    return CowriteTurn(
      sender: data['sender'] as String,
      text: data['text'] as String,
      feedback: data['feedback'] as String?,
      usedSuggestion: data['usedSuggestion'] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'text': text,
      'feedback': feedback,
      'usedSuggestion': usedSuggestion,
    };
  }
}

/// `learningSessions.cowriteTranscript`/`sender` values (`DATA_MODEL.md`
/// §4).
abstract final class CowriteSender {
  static const String siswa = 'siswa';
  static const String ai = 'ai';
}

/// A `learningSessions/{docId}` document (`DATA_MODEL.md` §4) — one
/// 3-phase learning session.
///
/// Milestone 6 only *reads* this collection, for Riwayat's "Per Sesi" tab
/// (list + read-only story replay via `utils/story_markers.dart`).
/// Nothing writes it yet — that's Milestone 7 — so every query returns an
/// empty list in practice until then. Same rationale as [LearningProgress]
/// for building the full shape now rather than partially.
class LearningSession {
  const LearningSession({
    required this.id,
    required this.studentId,
    required this.wordIds,
    required this.sourceType,
    required this.currentPhase,
    required this.storyTitle,
    required this.storyContent,
    required this.storyTranslation,
    required this.clozeTestResult,
    required this.cowriteTranscript,
    required this.cowriteWordsUsedCorrectly,
    required this.startedAt,
    required this.completedAt,
  });

  final String id;
  final String studentId;
  final List<String> wordIds;

  /// One of [LearningSessionSourceType].
  final String sourceType;

  /// One of [LearningSessionPhase].
  final String currentPhase;

  final String storyTitle;

  /// **Stored marked** (`[[kataTarget|bentukTerpakai]]`) — strip via
  /// `utils/story_markers.dart` before showing plain text, or parse via
  /// the same file to render the highlighted replay.
  final String storyContent;

  final String? storyTranslation;

  /// `{ wordId: wasCorrect }` — one entry per target word (one blank per
  /// word, `DATA_MODEL.md` §4).
  final Map<String, bool> clozeTestResult;

  final List<CowriteTurn> cowriteTranscript;

  /// wordIds used correctly *and* independently (without "saran menulis")
  /// during co-write — feeds the mastery calculation (`DATA_MODEL.md` §4).
  final List<String> cowriteWordsUsedCorrectly;

  final DateTime startedAt;
  final DateTime? completedAt;

  /// Fields with no `| null` in `DATA_MODEL.md` §4 that are also
  /// required from the moment a session document is first written (the
  /// document is created *at* the first story generation, itself driven
  /// by the target word list — `wordIds` and the story fields all exist
  /// from that first write). Deliberately **excludes**
  /// [cowriteTranscript]/[cowriteWordsUsedCorrectly]/[clozeTestResult]:
  /// those are also undocumented-as-nullable, but legitimately don't
  /// exist yet for a session still in an earlier phase, which is why
  /// [fromFirestore] gives *those* a lenient `?? []`/`?? {}` fallback
  /// instead of listing them here.
  static const List<String> _requiredFields = [
    'studentId',
    'wordIds',
    'sourceType',
    'currentPhase',
    'storyTitle',
    'storyContent',
    'startedAt',
  ];

  /// Throws a [FormatException] naming the failing document's `id` and
  /// the exact field, rather than letting a bare cast failure (e.g. a
  /// `TypeError` for a null value cast to a non-nullable `List`)
  /// propagate with nothing but a line number to go on —
  /// `LearningSessionService.fetchForStudent` queries by `studentId`
  /// alone (no `docId` filter, `DATA_MODEL.md` §4/`PROJECT_STATE.md`
  /// §5i), so more than one document can be in play at once, and knowing
  /// *which* `id` and *which* field failed is exactly the information a
  /// bare `TypeError` doesn't carry.
  ///
  /// Two layers, deliberately: the [_requiredFields] presence check below
  /// catches the common case (a field is missing or explicitly `null`)
  /// with an exact field name; the surrounding `try`/`catch` still guards
  /// against a field that's *present but the wrong type* (e.g. `wordIds`
  /// stored as a string instead of an array), which a presence check
  /// alone wouldn't catch.
  factory LearningSession.fromFirestore(String id, Map<String, dynamic> data) {
    for (final field in _requiredFields) {
      if (data[field] == null) {
        throw FormatException(
          'learningSessions/$id is missing required field "$field" '
          '(DATA_MODEL.md §4 does not mark this field nullable). '
          'Fields actually present on this document: ${data.keys.toList()}.',
        );
      }
    }

    try {
      final completedAtRaw = data['completedAt'];
      final clozeRaw = data['clozeTestResult'] as Map<String, dynamic>? ?? const {};
      return LearningSession(
        id: id,
        studentId: data['studentId'] as String,
        wordIds: [for (final w in data['wordIds'] as List) w as String],
        sourceType: data['sourceType'] as String,
        currentPhase: data['currentPhase'] as String,
        storyTitle: data['storyTitle'] as String,
        storyContent: data['storyContent'] as String,
        storyTranslation: data['storyTranslation'] as String?,
        clozeTestResult: {
          for (final entry in clozeRaw.entries) entry.key: entry.value as bool,
        },
        cowriteTranscript: [
          for (final raw in data['cowriteTranscript'] as List? ?? const [])
            CowriteTurn.fromMap(raw as Map<String, dynamic>),
        ],
        cowriteWordsUsedCorrectly: [
          for (final w in data['cowriteWordsUsedCorrectly'] as List? ?? const [])
            w as String,
        ],
        startedAt: (data['startedAt'] as Timestamp).toDate(),
        completedAt: completedAtRaw is Timestamp ? completedAtRaw.toDate() : null,
      );
    } catch (error) {
      throw FormatException(
        'learningSessions/$id has a missing or malformed required field '
        '(expected shape: DATA_MODEL.md §4). Fields actually present on '
        'this document: ${data.keys.toList()}. Underlying error: $error',
      );
    }
  }

  /// The write map for a session's **first** Firestore write — the moment
  /// Fase 1's first successful `/generate-story` call returns
  /// (`DATA_MODEL.md` §4: "Dokumen `learningSessions` mulai dibuat/di-
  /// upsert sejak cerita pertama berhasil di-generate"). `currentPhase`
  /// always starts at [LearningSessionPhase.membaca];
  /// `clozeTestResult`/`cowriteTranscript`/`cowriteWordsUsedCorrectly`
  /// start empty (nothing from later phases exists yet); `completedAt`
  /// starts `null`. Uses `FieldValue.serverTimestamp()` for `startedAt`,
  /// the same pattern `AppUser.newStudentData()` uses for `createdAt` —
  /// not a concrete client [Timestamp].
  static Map<String, dynamic> newSessionData({
    required String studentId,
    required List<String> wordIds,
    required String sourceType,
    required String storyTitle,
    required String storyContent,
    required String? storyTranslation,
  }) {
    return {
      'studentId': studentId,
      'wordIds': wordIds,
      'sourceType': sourceType,
      'currentPhase': LearningSessionPhase.membaca,
      'storyTitle': storyTitle,
      'storyContent': storyContent,
      'storyTranslation': storyTranslation,
      'clozeTestResult': <String, bool>{},
      'cowriteTranscript': <Map<String, dynamic>>[],
      'cowriteWordsUsedCorrectly': <String>[],
      'startedAt': FieldValue.serverTimestamp(),
      'completedAt': null,
    };
  }

  /// The write map for a **regenerate** while still in
  /// [LearningSessionPhase.membaca] — overwrites only the story fields
  /// (`DATA_MODEL.md` §4: "tiap kali siswa menekan Generate ulang... field
  /// storyTitle/storyContent/storyTranslation ditimpa langsung"). Never
  /// touches `wordIds`/`sourceType`/`currentPhase`/any later-phase field.
  static Map<String, dynamic> storyUpdateData({
    required String storyTitle,
    required String storyContent,
    required String? storyTranslation,
  }) {
    return {
      'storyTitle': storyTitle,
      'storyContent': storyContent,
      'storyTranslation': storyTranslation,
    };
  }
}
