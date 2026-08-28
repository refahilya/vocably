import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/topic.dart';
import '../models/vocab_word.dart';
import '../services/topics_service.dart';
import '../services/vocab_word_service.dart';
import '../utils/normalize_word.dart';
import 'ai_worker_providers.dart';

part 'vocab_management_providers.g.dart';

@riverpod
VocabWordService vocabWordService(Ref ref) => VocabWordService();

@riverpod
TopicsService topicsService(Ref ref) => TopicsService();

/// The canonical `topics` master list (`DATA_MODEL.md` §2b) — small
/// collection, always read live. Used by Tambah Kosakata's topic
/// multi-select chips.
@riverpod
Future<List<Topic>> topicsList(Ref ref) {
  return ref.watch(topicsServiceProvider).fetchAll();
}

/// Looks up an existing `vocabWords` document by [rawWord] (normalized
/// internally) — the "duplicate check on blur" step of Tambah Kosakata
/// (`SPEC.md` §4.1). `null` means the word doesn't exist yet.
@riverpod
Future<VocabWord?> vocabWordLookup(Ref ref, String rawWord) {
  final normalized = normalizeWord(rawWord);
  if (normalized.isEmpty) return Future.value(null);
  return ref.watch(vocabWordServiceProvider).findByWord(normalized);
}

/// One meaning row being drafted in the Tambah Kosakata form — a POS
/// plus its (auto-generated, not manually typed — `DESIGN_REFERENCE.md`
/// §5.4) Indonesian translation preview.
class MeaningDraft {
  const MeaningDraft({required this.pos, this.translation, this.isGenerating = false});

  final String pos;
  final String? translation;
  final bool isGenerating;

  MeaningDraft copyWith({String? pos, String? translation, bool? isGenerating}) {
    return MeaningDraft(
      pos: pos ?? this.pos,
      translation: translation ?? this.translation,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }
}

/// Drives the two guru "Tambah Kosakata" write flows (`SPEC.md` §4.1):
/// creating a brand-new word, or appending a new meaning to an existing
/// one. [state] reflects only these two "real" submissions — the
/// lighter-weight supporting actions ([generateTranslation],
/// [addNewTopic]) deliberately don't touch it, so a per-row translation
/// preview or adding one topic doesn't flip the whole form into a
/// submitting/disabled state.
@riverpod
class TambahKosakataController extends _$TambahKosakataController {
  @override
  FutureOr<void> build() {}

  /// Creates a brand-new word. Callers must have already confirmed (via
  /// [vocabWordLookupProvider]) that no document exists for this word —
  /// if one does, `firestore.rules` rejects this as `permission-denied`
  /// (a `set()` on an existing docId is evaluated as `update`, which the
  /// create-shape rule doesn't match).
  Future<void> createNewWord({
    required String word,
    required String cefrLevel,
    required List<String> topics,
    required List<MeaningDraft> meanings,
    required String teacherId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final normalized = normalizeWord(word);
      final vocabWordService = ref.read(vocabWordServiceProvider);
      await vocabWordService.createWord(
        word: normalized,
        meanings: [
          for (final draft in meanings)
            VocabMeaning(pos: draft.pos, translation: draft.translation),
        ],
        cefrLevel: cefrLevel,
        topics: topics,
        teacherId: teacherId,
      );
    });
  }

  /// Appends one new meaning to an existing word (`SPEC.md` §4.1's
  /// "Tambah makna baru ke kata ini").
  Future<void> appendMeaning({
    required String normalizedWord,
    required MeaningDraft meaning,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final vocabWordService = ref.read(vocabWordServiceProvider);
      await vocabWordService.appendMeaning(
        normalizedWord: normalizedWord,
        newMeaning: VocabMeaning(pos: meaning.pos, translation: meaning.translation),
      );
    });
  }

  /// Generates a translation preview for one meaning row via the Worker
  /// (`/translate`) — throws [AiWorkerException] on failure, left for the
  /// calling widget to catch and show inline (this deliberately doesn't
  /// touch [state], see the class doc comment).
  Future<String> generateTranslation({required String word, required String pos}) {
    return ref.read(aiWorkerServiceProvider).translate(word: normalizeWord(word), pos: pos);
  }

  /// Creates a new topic (or returns the existing one, if [name] already
  /// matches one) for the topic multi-select — see [TopicsService.
  /// createOrGetTopic]. Also deliberately doesn't touch [state].
  Future<Topic> addNewTopic({required String name, required String teacherId}) {
    return ref.read(topicsServiceProvider).createOrGetTopic(name: name, teacherId: teacherId);
  }
}
