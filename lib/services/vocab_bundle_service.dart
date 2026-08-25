import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/vocab_bundle_entry.dart';
import '../models/vocab_word.dart';
import '../utils/normalize_word.dart';
import 'firebase_service.dart';

/// Loads the static per-level vocabulary bundle (`DATA_MODEL.md` §11) and
/// merges it with newer/live Firestore data. Per `CLAUDE.md` §4, every
/// bundle load and every Firestore call lives here, not in a widget or
/// provider directly.
///
/// [assetBundle] defaults to Flutter's real [rootBundle] but is
/// injectable — mirrors [FirebaseService]'s own injectable-default
/// pattern already used by `AuthService`/`UserService` — so tests can
/// supply an in-memory fake instead of needing real asset files on disk.
class VocabBundleService {
  VocabBundleService({AssetBundle? assetBundle, FirebaseService? firebaseService})
    : _assetBundle = assetBundle ?? rootBundle,
      _firebaseService = firebaseService ?? const FirebaseService();

  final AssetBundle _assetBundle;
  final FirebaseService _firebaseService;

  CollectionReference<Map<String, dynamic>> get _vocabWords =>
      _firebaseService.firestore.collection('vocabWords');

  /// Reads and parses `assets/vocab/vocab_{level}.json` ([cefrLevel] is
  /// lowercased to build the filename — the asset itself is always
  /// lowercase per `DATA_MODEL.md` §11.2's naming). Returns an **empty
  /// list**, not an error, when the bundle file doesn't exist yet — both
  /// `DATA_MODEL.md` §2 and `SPEC.md` §3.2 document that a level (C2
  /// today, in principle any level) can legitimately have no content, and
  /// that must render as an empty state later, not a crash here. The
  /// catch is deliberately broad: any failure to read the asset (missing
  /// key, or whatever the underlying binding throws for that) is treated
  /// the same way.
  Future<List<VocabBundleEntry>> loadLevel(String cefrLevel) async {
    final assetKey = 'assets/vocab/vocab_${cefrLevel.toLowerCase()}.json';
    String raw;
    try {
      raw = await _assetBundle.loadString(assetKey);
    } catch (_) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return VocabBundleEntry.listFromJson(decoded);
  }

  /// `DATA_MODEL.md` §11.3 delta query — documents whose `cefrLevel`
  /// matches [cefrLevel] and whose `updatedAt` is newer than
  /// [bundleGeneratedAt] (a new word, or an existing word guru edited
  /// after the bundle was generated). Reuses [VocabWord.fromFirestore]
  /// for the actual Firestore parsing, then narrows each result to the
  /// bundle-shape fields via [VocabBundleEntry.fromVocabWord].
  Future<List<VocabBundleEntry>> fetchDelta({
    required String cefrLevel,
    required DateTime bundleGeneratedAt,
  }) async {
    final snapshot = await _vocabWords
        .where('cefrLevel', isEqualTo: cefrLevel)
        .where(
          'updatedAt',
          isGreaterThan: Timestamp.fromDate(bundleGeneratedAt),
        )
        .get();

    return [
      for (final doc in snapshot.docs)
        VocabBundleEntry.fromVocabWord(VocabWord.fromFirestore(doc.data())),
    ];
  }

  /// Loads a level's bundle and merges in anything newer from Firestore —
  /// the full flow `DATA_MODEL.md` §11.3 describes. New words are added;
  /// words present in both are replaced by the Firestore/delta version;
  /// nothing is duplicated. See [mergeBundleWithDelta] for the merge step
  /// itself, factored out separately so it's testable without Firestore.
  Future<List<VocabBundleEntry>> loadLevelWithDelta({
    required String cefrLevel,
    required DateTime bundleGeneratedAt,
  }) async {
    final bundle = await loadLevel(cefrLevel);
    final delta = await fetchDelta(
      cefrLevel: cefrLevel,
      bundleGeneratedAt: bundleGeneratedAt,
    );
    return mergeBundleWithDelta(bundle, delta);
  }
}

/// Pure merge step, factored out of [VocabBundleService.loadLevelWithDelta]
/// so it's independently testable without any Firestore/asset dependency.
/// Keyed by `normalizeWord(word)` (reusing the Stage 1 function, per
/// `CLAUDE.md` §8: the same normalization must be used everywhere a word
/// needs matching) so a delta entry always overwrites its bundle
/// counterpart rather than appearing as a duplicate — "kata baru
/// ditambahkan, kata yang sudah ada ditimpa versi Firestore-nya"
/// (`DATA_MODEL.md` §11.3).
List<VocabBundleEntry> mergeBundleWithDelta(
  List<VocabBundleEntry> bundle,
  List<VocabBundleEntry> delta,
) {
  final byWord = <String, VocabBundleEntry>{
    for (final entry in bundle) normalizeWord(entry.word): entry,
  };
  for (final entry in delta) {
    byWord[normalizeWord(entry.word)] = entry;
  }
  return byWord.values.toList();
}
