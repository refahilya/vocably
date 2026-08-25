/// Parsed response shape from `https://api.dictionaryapi.dev/api/v2/entries/en`
/// (`SPEC.md` §3.5, `DATA_MODEL.md` §2). This is English-only reference data
/// (definition, example sentence, phonetic spelling, whether a recorded
/// pronunciation exists) — it never carries the Indonesian translation,
/// which always comes from `VocabBundleEntry.meanings[].translationId`
/// instead (Firestore/bundle, not this API).
///
/// The live API actually returns a JSON **array** of these "entry"
/// objects (a word can have more than one homograph-style entry, each
/// with its own phonetics/meanings) — [DictionaryEntry.fromJsonArray]
/// flattens that array into one merged value, since the UI (`SPEC.md`
/// §3.5's card) doesn't need to distinguish "entry 1 vs entry 2" the way
/// the raw API does.
class DictionaryEntry {
  const DictionaryEntry({
    required this.word,
    required this.phoneticText,
    required this.hasAudio,
    required this.meaningsByPos,
  });

  final String word;

  /// e.g. `"/həˈloʊ/"` — `null` if the API supplied none at all (rare but
  /// not impossible; some entries only have per-`phonetics[]` text with
  /// none at the top level and none inside `phonetics[]` either).
  final String? phoneticText;

  /// Whether the API supplied at least one non-empty `phonetics[].audio`
  /// URL anywhere in the response. Deliberately **not** the URL itself —
  /// this app doesn't have an approved audio-file-playback dependency yet
  /// (see `word_detail_screen.dart`'s doc comment), so the only thing the
  /// UI needs from this is "does a real recording exist" for a future
  /// wire-up; playback today always goes through [TtsService] (Layer 2)
  /// regardless of this flag.
  final bool hasAudio;

  /// English definitions/examples grouped by part of speech, e.g.
  /// `{"noun": [...], "verb": [...]}` — merged across every entry the API
  /// returned. This is display-only reference data; it is **not** the
  /// source of truth for which POS values this word has in Vocably's own
  /// model (that's `VocabBundleEntry.posList`/`meanings`) — the API's POS
  /// labels don't always line up one-to-one with the bundle's, so the
  /// word-detail screen keys its own per-meaning blocks off the bundle
  /// entry and only uses this map to *enrich* a block when a matching key
  /// exists, never as the list of blocks to render.
  final Map<String, List<DictionaryDefinition>> meaningsByPos;

  static const _empty = <String, List<DictionaryDefinition>>{};

  /// Parses the raw decoded JSON array the API returns for a successful
  /// (200) lookup. Deliberately lenient field-by-field (a missing/wrong-
  /// typed optional field is skipped, not fatal) — this is third-party
  /// community data with no schema guarantee, and one odd field
  /// shouldn't take down the whole lookup (`SPEC.md` §3.5's Layer 1
  /// graceful-degradation principle applies here too, not just to
  /// missing entries entirely).
  factory DictionaryEntry.fromJsonArray(
    List<dynamic> entries, {
    required String word,
  }) {
    String? phoneticText;
    var hasAudio = false;
    final meaningsByPos = <String, List<DictionaryDefinition>>{};

    for (final rawEntry in entries) {
      if (rawEntry is! Map<String, dynamic>) continue;

      phoneticText ??= _stringOrNull(rawEntry['phonetic']);

      final phonetics = rawEntry['phonetics'];
      if (phonetics is List) {
        for (final rawPhonetic in phonetics) {
          if (rawPhonetic is! Map<String, dynamic>) continue;
          phoneticText ??= _stringOrNull(rawPhonetic['text']);
          final audio = _stringOrNull(rawPhonetic['audio']);
          if (audio != null && audio.isNotEmpty) hasAudio = true;
        }
      }

      final meanings = rawEntry['meanings'];
      if (meanings is List) {
        for (final rawMeaning in meanings) {
          if (rawMeaning is! Map<String, dynamic>) continue;
          final pos = _stringOrNull(rawMeaning['partOfSpeech']);
          if (pos == null) continue;

          final definitions = <DictionaryDefinition>[];
          final rawDefinitions = rawMeaning['definitions'];
          if (rawDefinitions is List) {
            for (final rawDefinition in rawDefinitions) {
              if (rawDefinition is! Map<String, dynamic>) continue;
              final text = _stringOrNull(rawDefinition['definition']);
              if (text == null) continue;
              definitions.add(
                DictionaryDefinition(
                  definition: text,
                  example: _stringOrNull(rawDefinition['example']),
                ),
              );
            }
          }
          if (definitions.isEmpty) continue;

          meaningsByPos.putIfAbsent(pos, () => []).addAll(definitions);
        }
      }
    }

    return DictionaryEntry(
      word: word,
      phoneticText: phoneticText,
      hasAudio: hasAudio,
      meaningsByPos: meaningsByPos.isEmpty ? _empty : meaningsByPos,
    );
  }

  static String? _stringOrNull(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }
}

/// One English definition + optional example sentence (`SPEC.md` §3.5).
class DictionaryDefinition {
  const DictionaryDefinition({required this.definition, this.example});

  final String definition;
  final String? example;
}
