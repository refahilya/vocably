import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/topic.dart';
import '../utils/topic_slug.dart';
import 'firebase_service.dart';

/// Thin wrapper around the `topics/{docId}` master-list collection
/// (`DATA_MODEL.md` §2b). Read for any signed-in user (topic-picker
/// chips/dropdowns); create is guru-only, enforced by
/// `firestore.rules` — this service doesn't check role itself, per
/// `CLAUDE.md` §4 (services are thin Firebase wrappers, not where
/// business rules live).
class TopicsService {
  TopicsService([FirebaseService? firebaseService])
    : _firebaseService = firebaseService ?? const FirebaseService();

  final FirebaseService _firebaseService;

  CollectionReference<Map<String, dynamic>> get _topics =>
      _firebaseService.firestore.collection('topics');

  /// The full canonical topic list, ordered by name — small collection,
  /// always read live from Firestore (`DATA_MODEL.md` §2b, unlike
  /// `vocabWords` which reads from the per-level bundle).
  Future<List<Topic>> fetchAll() async {
    final snapshot = await _topics.orderBy('name').get();
    return [for (final doc in snapshot.docs) Topic.fromFirestore(doc.data())];
  }

  /// Creates a new topic named [name] if one with the same
  /// [topicSlug]-computed `docId` doesn't already exist; otherwise
  /// returns the existing topic unchanged (`DATA_MODEL.md` §2b: "validasi
  /// uniqueness di application layer sebelum create"). Either way, the
  /// returned [Topic] is safe to immediately add to a word's `topics`
  /// array — its `name` is always the canonical stored name, even if
  /// [name]'s casing/whitespace differed slightly from what's already
  /// there.
  Future<Topic> createOrGetTopic({required String name, required String teacherId}) async {
    final trimmedName = name.trim();
    final docId = topicSlug(trimmedName);
    final docRef = _topics.doc(docId);

    final existing = await docRef.get();
    final existingData = existing.data();
    if (existingData != null) {
      return Topic.fromFirestore(existingData);
    }

    final data = Topic.newTeacherTopicData(name: trimmedName, teacherId: teacherId);
    await docRef.set(data);
    // `data`'s createdAt is a FieldValue.serverTimestamp() sentinel, not a
    // real Timestamp — resolve the return value locally instead of
    // re-reading, same reasoning `VocabWordService.createWord` uses.
    return Topic(name: trimmedName, createdBy: teacherId, createdAt: DateTime.now());
  }
}
