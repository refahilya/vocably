import 'package:cloud_firestore/cloud_firestore.dart';

/// A `topics/{docId}` document (`DATA_MODEL.md` §2b) — one entry in the
/// canonical master list of topic names guru can pick from (or add to)
/// when editing `vocabWords.topics`. `docId` is not a field on this
/// model — it's always `topicSlug(name)` (`utils/topic_slug.dart`),
/// computed rather than duplicated here, same convention as
/// `VocabWord`/`normalizeWord()`.
class Topic {
  const Topic({required this.name, required this.createdBy, required this.createdAt});

  /// Unique, human-readable topic name (e.g. `"Perjalanan"`) — the value
  /// referenced by `vocabWords.topics` elements.
  final String name;

  /// `"csvImport"` for topics seeded from the Oxford CSVs, or the `uid`
  /// of the guru who added this topic via "Tambah Kosakata"/"Edit Kata".
  final String createdBy;

  final DateTime createdAt;

  factory Topic.fromFirestore(Map<String, dynamic> data) {
    final createdAtRaw = data['createdAt'];
    return Topic(
      name: data['name'] as String,
      createdBy: data['createdBy'] as String,
      createdAt: createdAtRaw is Timestamp ? createdAtRaw.toDate() : DateTime.now(),
    );
  }

  /// Data for a brand-new topic document, created by a guru via the
  /// client (`DATA_MODEL.md` §2b's "alur tambah topik baru").
  static Map<String, dynamic> newTeacherTopicData({
    required String name,
    required String teacherId,
  }) {
    return {
      'name': name,
      'createdBy': teacherId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
