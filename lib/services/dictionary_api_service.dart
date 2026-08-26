import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/dictionary_entry.dart';

/// Why a lookup didn't produce a [DictionaryEntry] — lets the word-detail
/// screen phrase the right fallback message (`SPEC.md` §3.5 Layer 1)
/// instead of one generic "failed" state.
enum DictionaryLookupFailure {
  /// The API responded (any status) but has no entry for this word —
  /// the **expected, common** case for phrases (`SPEC.md` §3.5: "wake
  /// up", "look after"), not an error condition.
  notFound,

  /// Anything else: no network, timeout, non-200/404 status, or a
  /// response body that didn't decode as JSON. This community API has
  /// "no jaminan uptime" (`CLAUDE.md` §2), so this is expected too, just
  /// less often than [notFound].
  networkError,
}

/// Either a successful lookup or a reason it failed — deliberately not a
/// thrown exception for the "not found" case, since that's routine here,
/// not exceptional.
sealed class DictionaryLookupResult {
  const DictionaryLookupResult();
}

class DictionaryLookupSuccess extends DictionaryLookupResult {
  const DictionaryLookupSuccess(this.entry);
  final DictionaryEntry entry;
}

class DictionaryLookupError extends DictionaryLookupResult {
  const DictionaryLookupError(this.reason);
  final DictionaryLookupFailure reason;
}

/// Client for `https://api.dictionaryapi.dev/api/v2/entries/en` (`SPEC.md`
/// §3.5, `CLAUDE.md` §2). Called **directly from the client** — no secret
/// involved, so no Cloudflare Worker proxy here (unlike the ChatGPT
/// endpoints). This is English reference data only; it has nothing to do
/// with `meanings[].translation` (Indonesian) or the `/translate` Worker
/// endpoint (`DATA_MODEL.md` §2) — those are separate lookups this
/// service doesn't touch.
class DictionaryApiService {
  DictionaryApiService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://api.dictionaryapi.dev/api/v2/entries/en';

  /// `word` should already be `normalizeWord()`-ed by the caller (same as
  /// every other lookup key in this app) — this service doesn't
  /// re-normalize it itself, just URL-encodes whatever it's given.
  Future<DictionaryLookupResult> lookup(String word) async {
    final uri = Uri.parse('$_baseUrl/${Uri.encodeComponent(word)}');

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Covers no-connectivity, DNS failure, and timeout alike — none of
      // these are actionable differently by the caller, so one bucket.
      return const DictionaryLookupError(DictionaryLookupFailure.networkError);
    }

    if (response.statusCode == 404) {
      return const DictionaryLookupError(DictionaryLookupFailure.notFound);
    }
    if (response.statusCode != 200) {
      return const DictionaryLookupError(
        DictionaryLookupFailure.networkError,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return const DictionaryLookupError(
          DictionaryLookupFailure.networkError,
        );
      }
      return DictionaryLookupSuccess(
        DictionaryEntry.fromJsonArray(decoded, word: word),
      );
    } catch (_) {
      return const DictionaryLookupError(
        DictionaryLookupFailure.networkError,
      );
    }
  }
}
