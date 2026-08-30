import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/worker_config.dart';
import 'auth_service.dart';

/// Thrown by [AiWorkerService] on any failure — network error, a non-2xx
/// response, or an unexpected response shape. One bucket is enough here
/// (unlike `DictionaryApiService`'s notFound/networkError split): the
/// Worker's `/translate` doesn't have a meaningful "not found" case the
/// way a dictionary lookup does — any failure is "couldn't get a
/// translation right now," which every caller treats the same way
/// (`DESIGN_REFERENCE.md` §5.8: show a dim "—" placeholder, no error
/// screen).
class AiWorkerException implements Exception {
  const AiWorkerException(this.message);
  final String message;

  @override
  String toString() => 'AiWorkerException: $message';
}

/// One turn returned by `POST /cowrite-turn` (`DATA_MODEL.md` §10.2).
/// Deliberately separate from `models/learning_session.dart`'s
/// `CowriteTurn` (the *stored* transcript-entry shape) — this is the raw
/// Worker response shape, which has no `sender`/`usedSuggestion` (those
/// are the client's own bookkeeping, decided *after* this response comes
/// back per the "mandiri" rule — `DATA_MODEL.md` §10.2).
class CowriteTurnResult {
  const CowriteTurnResult({
    required this.aiTurn,
    required this.feedback,
    required this.hasError,
    required this.wordsUsedCorrectly,
    required this.suggestion,
    required this.aiUsedWords,
  });

  final String aiTurn;
  final String? feedback;
  final bool hasError;

  /// Target words (base form) the Worker judged were used correctly in
  /// the student's most recent turn — **not yet** filtered by the
  /// "mandiri" rule (`DATA_MODEL.md` §10.2: that filtering happens on the
  /// client, based on whether *this* turn used "saran menulis", which the
  /// Worker has no notion of).
  final List<String> wordsUsedCorrectly;

  /// Only non-null when the request had `requestSuggestion: true`.
  final String? suggestion;

  /// Milestone 7 Phase 2 Stage 8 (3-turn fallback): remaining target
  /// words the AI itself used in [aiTurn] this turn — empty in the
  /// normal case. Semantically distinct from [wordsUsedCorrectly] (the
  /// student's own usage): the client must union this into
  /// `allWordsUsedCorrectly` (so Cowrite can still end) but never into
  /// `independentWordsUsedCorrectly` (so it never counts as student
  /// mastery) — see `LearningFlowController.sendTurn`.
  final List<String> aiUsedWords;
}

/// One generated story, from `POST /generate-story` (`DATA_MODEL.md`
/// §10.2). [story] is returned **still marked** (`[[targetWord|usedForm]]`)
/// — callers parse/strip it via `utils/story_markers.dart`, never a raw
/// string search (`CLAUDE.md` §4).
class GenerateStoryResult {
  const GenerateStoryResult({required this.story, required this.translation});

  final String story;
  final String translation;
}

/// Client for the Cloudflare Worker AI proxy (`vocably-ai-worker`,
/// separate repo — `CLAUDE.md` §2/§7 Milestone 5, `DATA_MODEL.md` §10).
/// Every call attaches the signed-in user's Firebase ID token — the
/// Worker verifies it manually and doesn't care whether the caller is
/// siswa or guru (`DATA_MODEL.md` §10.1); that distinction only matters
/// for what the *caller* does with the result (guru writes it to
/// Firestore, siswa only displays it — `DATA_MODEL.md` §2).
class AiWorkerService {
  AiWorkerService({http.Client? client, AuthService? authService})
    : _client = client ?? http.Client(),
      _authService = authService ?? AuthService();

  final http.Client _client;
  final AuthService _authService;

  /// Translates [word] (already `normalizeWord()`-ed by the caller, same
  /// convention as every other lookup key in this app) for the given
  /// [pos], via `POST /translate`. Throws [AiWorkerException] on any
  /// failure — see that class's doc comment for why there's no more
  /// granular failure type.
  Future<String> translate({required String word, required String pos}) async {
    final decoded = await _postJson(
      path: '/translate',
      body: {'word': word, 'pos': pos},
    );

    final translation = decoded['translation'];
    if (translation is! String || translation.trim().isEmpty) {
      throw const AiWorkerException('AI proxy returned an unexpected response shape.');
    }
    return translation;
  }

  /// Generates a story via `POST /generate-story` — Fase 1 (`SPEC.md`
  /// §5.1, `DATA_MODEL.md` §10.2). [targetWords] must already be
  /// `normalizeWord()`-ed (same requirement `/translate` has); the Worker
  /// echoes them back verbatim inside each `[[targetWord|usedForm]]`
  /// marker, so any mismatch here would silently break every downstream
  /// marker match. [prompt] is the student's freely-typed title/context,
  /// any language, non-empty.
  ///
  /// A longer timeout than [translate]'s — this call involves a full
  /// chat-completion generation, plus the Worker's own one-shot retry if
  /// the model misses a marker (`DATA_MODEL.md` §10.2), so it can
  /// legitimately take longer than a single short lookup.
  Future<GenerateStoryResult> generateStory({
    required List<String> targetWords,
    required String prompt,
  }) async {
    final decoded = await _postJson(
      path: '/generate-story',
      body: {'targetWords': targetWords, 'prompt': prompt},
      timeout: const Duration(seconds: 45),
    );

    final story = decoded['story'];
    final translation = decoded['translation'];
    if (story is! String || story.isEmpty || translation is! String) {
      throw const AiWorkerException('AI proxy returned an unexpected response shape.');
    }
    return GenerateStoryResult(story: story, translation: translation);
  }

  /// One round of `POST /cowrite-turn` — Fase 3 (`SPEC.md` §5.3,
  /// `DATA_MODEL.md` §10.2). [transcript] is the conversation so far, each
  /// turn `{'sender': 'siswa'|'ai', 'text': ...}` (exactly the shape
  /// `vocably-ai-worker/src/handlers/cowriteTurn.ts` validates).
  /// [remainingWords] are target words (base form) not yet used
  /// correctly. [requestSuggestion] asks the Worker to also fill
  /// [CowriteTurnResult.suggestion].
  Future<CowriteTurnResult> cowriteTurn({
    required List<Map<String, String>> transcript,
    required List<String> remainingWords,
    required bool requestSuggestion,
  }) async {
    final decoded = await _postJson(
      path: '/cowrite-turn',
      body: {
        'transcript': transcript,
        'remainingWords': remainingWords,
        'requestSuggestion': requestSuggestion,
      },
      timeout: const Duration(seconds: 45),
    );

    final aiTurn = decoded['aiTurn'];
    final feedback = decoded['feedback'];
    final hasError = decoded['hasError'];
    final wordsUsedCorrectly = decoded['wordsUsedCorrectly'];
    final suggestion = decoded['suggestion'];
    final aiUsedWords = decoded['aiUsedWords'];
    if (aiTurn is! String ||
        (feedback != null && feedback is! String) ||
        hasError is! bool ||
        wordsUsedCorrectly is! List ||
        !wordsUsedCorrectly.every((w) => w is String) ||
        (suggestion != null && suggestion is! String) ||
        aiUsedWords is! List ||
        !aiUsedWords.every((w) => w is String)) {
      throw const AiWorkerException('AI proxy returned an unexpected response shape.');
    }
    return CowriteTurnResult(
      aiTurn: aiTurn,
      feedback: feedback as String?,
      hasError: hasError,
      wordsUsedCorrectly: [for (final w in wordsUsedCorrectly) w as String],
      suggestion: suggestion as String?,
      aiUsedWords: [for (final w in aiUsedWords) w as String],
    );
  }

  /// Shared request/error-handling plumbing for every endpoint: attach
  /// the ID token, POST the body, collapse any failure (missing token,
  /// network error, non-200, invalid JSON) into one [AiWorkerException] —
  /// see that class's doc comment for why there's no more granular
  /// failure type. Returns the decoded body as a `Map` (every endpoint's
  /// success response is a JSON object); a non-object body is itself
  /// treated as an unexpected shape.
  Future<Map<String, dynamic>> _postJson({
    required String path,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final idToken = await _authService.getIdToken();
    if (idToken == null) {
      throw const AiWorkerException('Not signed in.');
    }

    final uri = Uri.parse('$kWorkerBaseUrl$path');

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } catch (err) {
      throw AiWorkerException('Network error calling AI proxy: $err');
    }

    if (response.statusCode != 200) {
      throw AiWorkerException(
        'AI proxy returned ${response.statusCode}: ${response.body}',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AiWorkerException('AI proxy returned an unexpected response shape.');
      }
      return decoded;
    } on AiWorkerException {
      rethrow;
    } catch (err) {
      throw AiWorkerException('Failed to parse AI proxy response: $err');
    }
  }
}
