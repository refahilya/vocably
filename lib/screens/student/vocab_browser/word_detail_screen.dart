import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/dictionary_entry.dart';
import '../../../models/vocab_bundle_entry.dart';
import '../../../models/vocab_word.dart';
import '../../../providers/dictionary_providers.dart';
import '../../../providers/lazy_translation_providers.dart';
import '../../../providers/learning_cart_providers.dart';
import '../../../services/dictionary_api_service.dart';
import '../../../theme/theme.dart';
import '../../../utils/normalize_word.dart';

/// Milestone 4 Stage 11/12 — "Kamus Detail" (`SPEC.md` §3.5). Reached by
/// tapping a word's name/translation area in [VocabBrowserScreen]'s list
/// (the trailing cart icon stays a separate tap target, see that file).
///
/// **Deliberately simplified relative to `DESIGN_REFERENCE.md` §3.2's**
/// full "card appears inline below the chip grid" pattern — this stage's
/// browse screen is a flat list, not that chip grid, so the detail view
/// is its own pushed screen instead, matching how [VocabBrowserScreen]
/// itself already deviates from §5.7 for the same reason (see that
/// file's doc comment).
///
/// **Known scope limitation, not a bug:** the speaker button always uses
/// [TtsService] (browser/OS text-to-speech), never DictionaryAPI's own
/// recorded-audio file, even when [DictionaryEntry.hasAudio] is true.
/// Playing that file back would need an audio-file-playback package
/// (e.g. `audioplayers`) that isn't on the approved dependency list
/// (`CLAUDE.md` §6) — flagged for a decision, not added silently.
class WordDetailScreen extends ConsumerWidget {
  const WordDetailScreen({super.key, required this.entry});

  final VocabBundleEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalized = normalizeWord(entry.word);
    final lookupAsync = ref.watch(dictionaryLookupProvider(normalized));
    final inCart = ref
        .watch(learningCartProvider)
        .containsKey(normalized);

    return Scaffold(
      appBar: AppBar(title: Text(entry.word)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderCard(
              entry: entry,
              lookupAsync: lookupAsync,
              inCart: inCart,
              onToggleCart: () =>
                  ref.read(learningCartProvider.notifier).toggle(entry),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final meaning in entry.meanings)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _MeaningBlock(
                  word: entry.word,
                  meaning: meaning,
                  content: _dictionaryContentFor(lookupAsync, meaning.pos),
                  onRetry: () => ref.invalidate(dictionaryLookupProvider(normalized)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// What a [_MeaningBlock] should show for its English-content area —
/// computed once here from the lookup's [AsyncValue] state rather than a
/// flat nullable list, so "still loading", "a transient failure worth
/// retrying", and "this word/POS genuinely has no English content" are
/// distinguishable (Milestone 4 bug fix: previously all three collapsed
/// into the exact same "not available" text, which is wrong for the
/// first two — a loading lookup isn't "unavailable", and a network/rate-
/// limit hiccup is retryable, unlike a genuine content gap).
sealed class _DictionaryContent {
  const _DictionaryContent();
}

class _DictionaryLoading extends _DictionaryContent {
  const _DictionaryLoading();
}

class _DictionaryFound extends _DictionaryContent {
  const _DictionaryFound(this.definitions);
  final List<DictionaryDefinition> definitions;
}

/// Genuinely no English content for this word/POS — either the API has
/// no entry at all (`DictionaryLookupFailure.notFound`, the documented-
/// as-normal case for phrases etc.), or it has an entry but neither the
/// exact POS tag nor any known alias matched anything.
class _DictionaryUnavailable extends _DictionaryContent {
  const _DictionaryUnavailable();
}

/// A transient failure (network error, rate limiting, an unexpected
/// malformed response) — unlike [_DictionaryUnavailable], retrying might
/// well succeed, so the UI offers a retry action instead of presenting
/// it identically to a permanent content gap.
class _DictionaryRetryable extends _DictionaryContent {
  const _DictionaryRetryable();
}

_DictionaryContent _dictionaryContentFor(
  AsyncValue<DictionaryLookupResult> lookupAsync,
  String pos,
) {
  return lookupAsync.when(
    loading: () => const _DictionaryLoading(),
    // The service itself never throws (DictionaryApiService.lookup always
    // returns a DictionaryLookupResult) — an AsyncError here would only
    // come from something unexpected at the provider level, so treat it
    // the same as a transient failure: retryable, not a permanent gap.
    error: (_, _) => const _DictionaryRetryable(),
    data: (result) => switch (result) {
      DictionaryLookupSuccess(entry: final dictEntry) =>
        switch (dictEntry.definitionsForPos(pos)) {
          final defs? when defs.isNotEmpty => _DictionaryFound(defs),
          _ => const _DictionaryUnavailable(),
        },
      DictionaryLookupError(reason: DictionaryLookupFailure.notFound) =>
        const _DictionaryUnavailable(),
      DictionaryLookupError(reason: DictionaryLookupFailure.networkError) =>
        const _DictionaryRetryable(),
    },
  );
}

class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({
    required this.entry,
    required this.lookupAsync,
    required this.inCart,
    required this.onToggleCart,
  });

  final VocabBundleEntry entry;
  final AsyncValue<DictionaryLookupResult> lookupAsync;
  final bool inCart;
  final VoidCallback onToggleCart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phoneticText = lookupAsync.whenOrNull(
      data: (result) => switch (result) {
        DictionaryLookupSuccess(entry: final dictEntry) =>
          dictEntry.phoneticText,
        DictionaryLookupError() => null,
      },
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.word.toUpperCase(), style: AppTextStyles.wordTitle),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    if (phoneticText != null) ...[
                      Text(
                        phoneticText,
                        style: AppTextStyles.body.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    // SPEC.md §3.5: "Pronunciation... + tombol putar
                    // audio" — see the class doc comment on why this
                    // always goes through TTS rather than a real
                    // recording.
                    IconButton(
                      icon: const Icon(Icons.volume_up),
                      tooltip: 'Putar pengucapan',
                      color: AppColors.primary,
                      onPressed: () =>
                          ref.read(ttsServiceProvider).speak(entry.word),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _Badge(text: entry.cefrLevel, emphasized: true),
                    for (final topic in entry.topics) _Badge(text: topic),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(inCart ? Icons.check_circle : Icons.add_circle_outline),
            color: inCart ? AppColors.success : AppColors.primary,
            tooltip: inCart
                ? 'Hapus dari Keranjang Pelajari'
                : 'Tambah ke Keranjang Pelajari',
            onPressed: onToggleCart,
          ),
        ],
      ),
    );
  }
}

/// One block per Vocably meaning (`DESIGN_REFERENCE.md` §3.2: "satu blok
/// per makna... badge POS berwarna, badge bendera 🇮🇩 + terjemahan khusus
/// makna itu, dan bullet definisi"). [dictionaryDefinitions] enriches the
/// block with English definitions/examples **when the API happened to
/// return a matching POS key** — absent (either the API had no entry at
/// all, or had one but not for this exact POS) degrades to just the
/// Vocably data, per `SPEC.md` §3.5 Layer 1.
class _MeaningBlock extends ConsumerWidget {
  const _MeaningBlock({
    required this.word,
    required this.meaning,
    required this.content,
    required this.onRetry,
  });

  final String word;
  final VocabMeaning meaning;
  final _DictionaryContent content;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.disabledBackground),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Badge(text: meaning.pos, emphasized: true),
              const SizedBox(width: AppSpacing.sm),
              const Text('🇮🇩 '),
              if (meaning.translation != null)
                Expanded(
                  child: Text(
                    meaning.translation!,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                // DATA_MODEL.md §2 point 4 / DESIGN_REFERENCE.md §5.8:
                // an empty translation is generated lazily via the
                // Worker and shown on-screen only — never written back
                // to Firestore (see LazyTranslationText's doc comment).
                Expanded(child: _LazyTranslationText(word: word, pos: meaning.pos)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          switch (content) {
            _DictionaryLoading() => Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Memuat definisi...',
                  style: AppTextStyles.body.copyWith(color: Colors.black45),
                ),
              ],
            ),
            _DictionaryUnavailable() => Text(
              'Definisi bahasa Inggris tidak tersedia untuk kata ini.',
              style: AppTextStyles.body.copyWith(color: Colors.black45),
            ),
            _DictionaryRetryable() => Row(
              children: [
                Expanded(
                  child: Text(
                    'Gagal memuat definisi. Periksa koneksi lalu coba lagi.',
                    style: AppTextStyles.body.copyWith(color: Colors.black45),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
              ],
            ),
            _DictionaryFound(:final definitions) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final definition in definitions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•  ${definition.definition}', style: AppTextStyles.body),
                        if (definition.example != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.md,
                              top: 2,
                            ),
                            child: Text(
                              '"${definition.example}"',
                              style: AppTextStyles.body.copyWith(
                                color: Colors.black54,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          },
        ],
      ),
    );
  }
}

/// Fills in a meaning's empty `translation` on-screen by calling the
/// Worker's `/translate` (`DATA_MODEL.md` §2 point 4) — never written
/// back to Firestore; `lazyTranslationProvider` caches the result in
/// memory for the rest of the session (see its own doc comment), so
/// reopening this word/meaning during the same session doesn't call the
/// Worker again. `DESIGN_REFERENCE.md` §5.8: skeleton while loading, a
/// dim "—" if the Worker call also fails — never an error screen.
class _LazyTranslationText extends ConsumerWidget {
  const _LazyTranslationText({required this.word, required this.pos});

  final String word;
  final String pos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalized = normalizeWord(word);
    final translationAsync = ref.watch(lazyTranslationProvider(normalized, pos));

    return translationAsync.when(
      loading: () => Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Menerjemahkan...',
            style: AppTextStyles.body.copyWith(
              color: Colors.black45,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      error: (_, _) => Text(
        '—',
        style: AppTextStyles.body.copyWith(color: Colors.black45),
      ),
      data: (translation) => Text(
        translation,
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.emphasized = false});

  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: emphasized ? AppColors.primary : AppColors.disabledBackground,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: AppTextStyles.badgeLabel.copyWith(
          color: emphasized ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}
