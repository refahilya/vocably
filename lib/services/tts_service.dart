import 'package:flutter_tts/flutter_tts.dart';

/// Browser text-to-speech (`SPEC.md` §3.5 "Lapisan 2 — audio (wajib)"),
/// via the `flutter_tts` package — the dependency `CLAUDE.md`/
/// `DATA_MODEL.md` had flagged as "belum dikonfirmasi", now approved.
///
/// This is deliberately the **only** pronunciation-playback path Milestone
/// 4 wires up, even for words where DictionaryAPI supplies a real
/// recorded-audio URL (`DictionaryEntry.hasAudio`). Playing that file back
/// would need an audio-file-playback package (e.g. `audioplayers`/
/// `just_audio`), which is not on the approved list — see the note in
/// `word_detail_screen.dart`. TTS reads the word aloud either way, so the
/// speaker button is always useful, just not always "the real recording".
class TtsService {
  TtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    // English pronunciation regardless of device locale — this button
    // always reads an English vocabulary word, never Indonesian text.
    _tts.setLanguage('en-US');
  }

  final FlutterTts _tts;

  /// Speaks [word]. Errors (no TTS voices installed, browser refusal,
  /// etc.) are swallowed here — the caller shows its own inline
  /// "pengucapan tidak tersedia" state rather than a thrown exception,
  /// consistent with this feature being an optional nicety, not a
  /// blocking one (`SPEC.md` §3.5 Layer 2: "jauh lebih baik daripada
  /// tombol putar yang mati", not "must never fail").
  Future<bool> speak(String word) async {
    try {
      final result = await _tts.speak(word);
      // flutter_tts returns 1 on success on most platforms.
      return result == 1;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Nothing meaningful to do if stop itself fails.
    }
  }
}
