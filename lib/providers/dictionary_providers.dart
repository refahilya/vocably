import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/dictionary_api_service.dart';
import '../services/tts_service.dart';

part 'dictionary_providers.g.dart';

@Riverpod(keepAlive: true)
DictionaryApiService dictionaryApiService(Ref ref) => DictionaryApiService();

@Riverpod(keepAlive: true)
TtsService ttsService(Ref ref) => TtsService();

/// One lookup per normalized word — a family provider so opening the same
/// word twice in a session (e.g. back out of the detail screen, tap it
/// again) doesn't re-hit the API, matching `SPEC.md` §3.5's "boleh
/// di-cache di memori selama sesi aplikasi berjalan supaya tidak dipanggil
/// berulang" (written there for the Indonesian `/translate` lazy-display
/// call, but the same reasoning applies here). Not `keepAlive` — once
/// nothing is watching a given word anymore (detail screen popped, and
/// the user never reopens it), Riverpod disposes it like any other
/// `FutureProvider`, so this doesn't grow into an unbounded in-memory
/// cache over a long session.
@riverpod
Future<DictionaryLookupResult> dictionaryLookup(Ref ref, String word) {
  return ref.watch(dictionaryApiServiceProvider).lookup(word);
}
