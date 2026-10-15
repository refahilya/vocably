// Co-Write "Saran menulis" text handling (`SPEC.md` §5.3).
//
// The Worker returns the suggestion as a bare English sentence; the
// student-facing instruction around it is always Indonesian and is added
// here, in application code, never by the model:
// `Coba tulis "I order a cup of coffee."`.

final RegExp _suggestionPrefix = RegExp(
  r'^\s*(?:(?:you\s+(?:could|can|might)\s+(?:write|say|try)|try\s+(?:to\s+)?(?:write|saying|writing)|try|suggestion|example|coba\s+tulis(?:kan)?|contoh)\s*[:\-–]?\s*)',
  caseSensitive: false,
);

final RegExp _surroundingQuotes = RegExp(r'''^["“'‘](.*)["”'’]$''', dotAll: true);

/// Reduces [raw] to the bare English sentence: strips an instruction prefix
/// (`Try to write:`, `You could write:`, `Coba tulis`) and surrounding
/// quotes. Mirrors the Worker's `extractSuggestedSentence`
/// (`vocably-ai-worker/src/cowriteValidator.ts`); kept client-side too as
/// a defensive fallback for responses from an older deployed Worker that
/// still prefixed suggestions in English.
String extractSuggestedSentence(String raw) {
  var text = raw.trim().replaceFirst(_suggestionPrefix, '').trim();
  final quoted = _surroundingQuotes.firstMatch(text);
  if (quoted != null) text = quoted.group(1)!.trim();
  return text;
}

/// The student-facing suggestion line: Indonesian instruction, English
/// example sentence.
String formatWritingSuggestion(String sentence) => 'Coba tulis "$sentence"';
