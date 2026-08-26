import 'package:cloud_firestore/cloud_firestore.dart';

/// One meaning of a [VocabWord] — a single part-of-speech plus its
/// Indonesian translation. A word can have more than one of these (e.g.
/// "souvenir" as a noun vs. a verb, each with its own translation) — see
/// `DATA_MODEL.md` §2's rationale for why this is an array of maps rather
/// than a single `pos`/`translation` pair on the word itself.
class VocabMeaning {
  const VocabMeaning({required this.pos, this.translation});

  /// e.g. `"noun"`, `"verb"`.
  final String pos;

  /// Indonesian translation for this specific meaning. Nullable — a
  /// translation that failed to generate (or hasn't been generated yet)
  /// stays `null` until dev/guru fills it in. Students never write this
  /// field (`CLAUDE.md` §8 "Bank kosakata" — `vocabWords` is read-only
  /// total for siswa).
  final String? translation;

  factory VocabMeaning.fromMap(Map<String, dynamic> data) {
    return VocabMeaning(
      pos: data['pos'] as String,
      translation: data['translation'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {'pos': pos, 'translation': translation};
  }
}

/// A `vocabWords/{docId}` document (`DATA_MODEL.md` §2). `docId` itself is
/// not a field on this model — it is always `normalizeWord(word)`,
/// computed via [normalizeWord] rather than duplicated here.
///
/// This models the **full Firestore document shape** exactly as
/// documented — every field the schema table lists is required unless the
/// table itself marks it nullable. It deliberately does *not* try to also
/// accommodate the smaller per-level bundle JSON shape (`DATA_MODEL.md`
/// §11.2 excludes `source`/`addedByTeacherId`/`createdAt` from bundles,
/// and doesn't include `updatedAt` there either) — reconciling that
/// narrower shape against this model is Milestone 4's bundle-loading
/// stage's concern, not this one's (see Stage 1 report).
class VocabWord {
  VocabWord({
    required this.word,
    required this.meanings,
    required this.cefrLevel,
    required this.topics,
    required this.source,
    this.addedByTeacherId,
    required this.createdAt,
    required this.updatedAt,
  }) : assert(
         meanings.isNotEmpty,
         'VocabWord requires at least one meaning',
       );

  /// Already normalized (`normalizeWord(raw)`) — same string as this
  /// document's `docId`.
  final String word;

  /// One or more meanings. **`meanings[0]` is the documented primary
  /// meaning** (`DATA_MODEL.md` §2: "makna utama... dipakai untuk
  /// terjemahan ringkas di chip/list") — order is the convention itself,
  /// there is no separate `isPrimary` flag. See [primaryMeaning].
  final List<VocabMeaning> meanings;

  /// `"A1"`–`"C2"`. Actual data currently only covers A1–C1 (Oxford
  /// 3000/5000 source); `C2` is a valid value with no guarantee of
  /// content yet (`CLAUDE.md` §8 "Level CEFR").
  final String cefrLevel;

  /// A word can belong to more than one topic. Each element is expected to
  /// reference a `topics.name` (`DATA_MODEL.md` §2b) — not validated by
  /// this model.
  final List<String> topics;

  /// `"oxford3000"` | `"oxford5000"` | `"guru"`.
  final String source;

  /// `uid` of the teacher who added this word — only present when
  /// `source == "guru"`, `null` otherwise.
  final String? addedByTeacherId;

  final DateTime createdAt;

  /// Updated on every write, including creation (`updatedAt == createdAt`
  /// for a brand-new document). This is the field the bundle delta query
  /// (`DATA_MODEL.md` §11.3) filters on.
  final DateTime updatedAt;

  /// **Derived, not trusted from source data.** Always computed fresh from
  /// [meanings] rather than read from whatever a source document's
  /// `posList` field happens to contain — mirrors `DATA_MODEL.md` §2's
  /// invariant ("turunan otomatis... jangan diisi manual, selalu re-sync
  /// tiap `meanings` berubah") as strictly as Dart allows. Firestore
  /// itself still has to persist a real `posList` field (it has no
  /// computed fields), so a future writer should read *this* getter to
  /// know what value to persist, rather than deriving it separately and
  /// risking drift.
  List<String> get posList => [for (final meaning in meanings) meaning.pos];

  /// The documented "primary meaning" convention — `meanings[0]`.
  VocabMeaning get primaryMeaning => meanings.first;

  factory VocabWord.fromFirestore(Map<String, dynamic> data) {
    final createdAtRaw = data['createdAt'];
    final updatedAtRaw = data['updatedAt'];
    return VocabWord(
      word: data['word'] as String,
      meanings: [
        for (final raw in data['meanings'] as List)
          VocabMeaning.fromMap(raw as Map<String, dynamic>),
      ],
      cefrLevel: data['cefrLevel'] as String,
      topics: [for (final topic in data['topics'] as List) topic as String],
      source: data['source'] as String,
      addedByTeacherId: data['addedByTeacherId'] as String?,
      createdAt: createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : DateTime.now(),
      updatedAt: updatedAtRaw is Timestamp
          ? updatedAtRaw.toDate()
          : DateTime.now(),
    );
  }

  /// Inverse of [fromFirestore] — includes the derived [posList] because
  /// Firestore has no computed fields and genuinely needs it stored
  /// (`DATA_MODEL.md` §2).
  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'meanings': [for (final meaning in meanings) meaning.toMap()],
      'posList': posList,
      'cefrLevel': cefrLevel,
      'topics': topics,
      'source': source,
      'addedByTeacherId': addedByTeacherId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
