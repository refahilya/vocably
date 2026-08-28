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

/// Client for the Cloudflare Worker AI proxy (`vocably-ai-worker`,
/// separate repo — `CLAUDE.md` §2/§7 Milestone 5, `DATA_MODEL.md` §10).
/// Every call attaches the signed-in user's Firebase ID token — the
/// Worker verifies it manually and doesn't care whether the caller is
/// siswa or guru (`DATA_MODEL.md` §10.1); that distinction only matters
/// for what the *caller* does with the result (guru writes it to
/// Firestore, siswa only displays it — `DATA_MODEL.md` §2).
///
/// Only `/translate` is implemented on this side so far — `/generate-
/// story` and `/cowrite-turn` exist on the Worker (`CLAUDE.md` §7
/// Milestone 5's Worker-setup step lists all three), but have no Flutter
/// caller until Milestone 7 builds the 3-phase learning flow.
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
    final idToken = await _authService.getIdToken();
    if (idToken == null) {
      throw const AiWorkerException('Not signed in.');
    }

    final uri = Uri.parse('$kWorkerBaseUrl/translate');

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'word': word, 'pos': pos}),
          )
          .timeout(const Duration(seconds: 15));
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
      final translation = decoded is Map<String, dynamic> ? decoded['translation'] : null;
      if (translation is! String || translation.trim().isEmpty) {
        throw const AiWorkerException('AI proxy returned an unexpected response shape.');
      }
      return translation;
    } on AiWorkerException {
      rethrow;
    } catch (err) {
      throw AiWorkerException('Failed to parse AI proxy response: $err');
    }
  }
}
