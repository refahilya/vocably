import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../models/topic.dart';
import '../../../providers/vocab_management_providers.dart';
import '../../../services/ai_worker_service.dart';
import '../../../theme/theme.dart';
import '../../../utils/cefr_levels.dart';
import '../../../utils/normalize_word.dart';

/// Guru "Tambah Kosakata" (`SPEC.md` §4.1, `DESIGN_REFERENCE.md` §5.4) —
/// the real screen behind the "Kosakata" nav destination, replacing
/// `VocabManagementPlaceholder`. Milestone 5 scope only: adding a new
/// word (with duplicate detection + append-meaning) — "Edit Kata" is a
/// separate screen Milestone 8 adds, per the project owner's decision
/// not to build an inert segmented-control shell for it ahead of time.
class TambahKosakataScreen extends ConsumerStatefulWidget {
  const TambahKosakataScreen({super.key, required this.profile});

  final AppUser profile;

  @override
  ConsumerState<TambahKosakataScreen> createState() => _TambahKosakataScreenState();
}

class _TambahKosakataScreenState extends ConsumerState<TambahKosakataScreen> {
  final _wordController = TextEditingController();
  final _wordFocusNode = FocusNode();
  final _newTopicController = TextEditingController();

  String _cefrLevel = kCefrLevels.first;
  final List<String> _selectedTopics = [];
  List<MeaningDraft> _meanings = const [MeaningDraft(pos: '')];

  /// The word last committed for a duplicate check (set when the word
  /// field loses focus) — deliberately not "every keystroke", so this
  /// doesn't fire a Firestore read per character typed.
  String _wordToCheck = '';

  bool _isAddingTopic = false;
  String? _topicError;

  @override
  void initState() {
    super.initState();
    _wordFocusNode.addListener(_onWordFocusChange);
  }

  @override
  void dispose() {
    _wordFocusNode.removeListener(_onWordFocusChange);
    _wordController.dispose();
    _wordFocusNode.dispose();
    _newTopicController.dispose();
    super.dispose();
  }

  void _onWordFocusChange() {
    if (!_wordFocusNode.hasFocus) {
      final trimmed = _wordController.text.trim();
      if (trimmed != _wordToCheck) {
        setState(() => _wordToCheck = trimmed);
      }
    }
  }

  void _updateMeaning(int index, MeaningDraft Function(MeaningDraft) update) {
    setState(() {
      _meanings = [
        for (var i = 0; i < _meanings.length; i++)
          if (i == index) update(_meanings[i]) else _meanings[i],
      ];
    });
  }

  void _addMeaningRow() {
    setState(() => _meanings = [..._meanings, const MeaningDraft(pos: '')]);
  }

  void _removeMeaningRow(int index) {
    if (_meanings.length <= 1) return;
    setState(() => _meanings = [for (var i = 0; i < _meanings.length; i++) if (i != index) _meanings[i]]);
  }

  Future<void> _generateTranslation(int index) async {
    final pos = _meanings[index].pos.trim();
    final word = _wordController.text.trim();
    if (pos.isEmpty || word.isEmpty) return;

    _updateMeaning(index, (m) => m.copyWith(isGenerating: true));
    try {
      final translation = await ref
          .read(tambahKosakataControllerProvider.notifier)
          .generateTranslation(word: word, pos: pos);
      _updateMeaning(index, (m) => m.copyWith(translation: translation, isGenerating: false));
    } on AiWorkerException {
      _updateMeaning(index, (m) => m.copyWith(isGenerating: false));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuat terjemahan. Coba lagi.')),
      );
    }
  }

  Future<void> _addNewTopic() async {
    final name = _newTopicController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isAddingTopic = true;
      _topicError = null;
    });
    try {
      final topic = await ref
          .read(tambahKosakataControllerProvider.notifier)
          .addNewTopic(name: name, teacherId: widget.profile.uid);
      ref.invalidate(topicsListProvider);
      setState(() {
        if (!_selectedTopics.contains(topic.name)) {
          _selectedTopics.add(topic.name);
        }
        _newTopicController.clear();
        _isAddingTopic = false;
      });
    } catch (_) {
      setState(() {
        _isAddingTopic = false;
        _topicError = 'Gagal menambah topik. Coba lagi.';
      });
    }
  }

  bool get _canSubmitNewWord {
    if (_wordController.text.trim().isEmpty) return false;
    if (_meanings.isEmpty) return false;
    return _meanings.every((m) => m.pos.trim().isNotEmpty && m.translation != null);
  }

  Future<void> _submitNewWord() async {
    final controller = ref.read(tambahKosakataControllerProvider.notifier);
    await controller.createNewWord(
      word: _wordController.text.trim(),
      cefrLevel: _cefrLevel,
      topics: _selectedTopics,
      meanings: _meanings,
      teacherId: widget.profile.uid,
    );
    if (!mounted) return;
    final state = ref.read(tambahKosakataControllerProvider);
    if (!state.hasError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kata baru berhasil ditambahkan.')));
      setState(() {
        _wordController.clear();
        _wordToCheck = '';
        _selectedTopics.clear();
        _meanings = const [MeaningDraft(pos: '')];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final duplicateLookup = _wordToCheck.isEmpty
        ? null
        : ref.watch(vocabWordLookupProvider(_wordToCheck));
    final controllerState = ref.watch(tambahKosakataControllerProvider);
    final topicsAsync = ref.watch(topicsListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tambah Kosakata',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _wordController,
            focusNode: _wordFocusNode,
            decoration: const InputDecoration(labelText: 'Kata (Bahasa Inggris)'),
            onSubmitted: (_) => _wordFocusNode.unfocus(),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (duplicateLookup != null)
            duplicateLookup.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: LinearProgressIndicator(),
              ),
              error: (_, _) => const SizedBox.shrink(),
              data: (existing) => existing == null
                  ? const SizedBox.shrink()
                  : _DuplicateWordNotice(
                      word: _wordToCheck,
                      profile: widget.profile,
                    ),
            ),
          if (duplicateLookup == null || (duplicateLookup.value == null))
            _NewWordForm(
              cefrLevel: _cefrLevel,
              onCefrLevelChanged: (level) => setState(() => _cefrLevel = level),
              selectedTopics: _selectedTopics,
              topicsAsync: topicsAsync,
              onToggleTopic: (name) => setState(() {
                if (_selectedTopics.contains(name)) {
                  _selectedTopics.remove(name);
                } else {
                  _selectedTopics.add(name);
                }
              }),
              newTopicController: _newTopicController,
              isAddingTopic: _isAddingTopic,
              topicError: _topicError,
              onAddTopic: _addNewTopic,
              meanings: _meanings,
              onMeaningPosChanged: (i, pos) =>
                  _updateMeaning(i, (m) => m.copyWith(pos: pos, translation: null)),
              onGenerateTranslation: _generateTranslation,
              onAddMeaningRow: _addMeaningRow,
              onRemoveMeaningRow: _removeMeaningRow,
              canSubmit: _canSubmitNewWord && !controllerState.isLoading,
              isSubmitting: controllerState.isLoading,
              onSubmit: _submitNewWord,
              errorMessage: controllerState.hasError
                  ? 'Gagal menyimpan kata. Periksa koneksi lalu coba lagi.'
                  : null,
            ),
        ],
      ),
    );
  }
}

/// Shown when [duplicateLookup] found an existing word — offers the
/// compact "add a new meaning to this word" flow instead of a raw error
/// (`SPEC.md` §4.1).
class _DuplicateWordNotice extends ConsumerStatefulWidget {
  const _DuplicateWordNotice({required this.word, required this.profile});

  final String word;
  final AppUser profile;

  @override
  ConsumerState<_DuplicateWordNotice> createState() => _DuplicateWordNoticeState();
}

class _DuplicateWordNoticeState extends ConsumerState<_DuplicateWordNotice> {
  MeaningDraft _draft = const MeaningDraft(pos: '');
  bool _expanded = false;

  Future<void> _generate() async {
    final pos = _draft.pos.trim();
    if (pos.isEmpty) return;
    setState(() => _draft = _draft.copyWith(isGenerating: true));
    try {
      final translation = await ref
          .read(tambahKosakataControllerProvider.notifier)
          .generateTranslation(word: widget.word, pos: pos);
      setState(() => _draft = _draft.copyWith(translation: translation, isGenerating: false));
    } on AiWorkerException {
      setState(() => _draft = _draft.copyWith(isGenerating: false));
    }
  }

  Future<void> _submit() async {
    final controller = ref.read(tambahKosakataControllerProvider.notifier);
    await controller.appendMeaning(normalizedWord: normalizeWord(widget.word), meaning: _draft);
    if (!mounted) return;
    final state = ref.read(tambahKosakataControllerProvider);
    if (!state.hasError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Makna baru berhasil ditambahkan.')));
      setState(() {
        _expanded = false;
        _draft = const MeaningDraft(pos: '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(tambahKosakataControllerProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kata ini sudah ada di bank kosakata.', style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.xs),
          if (!_expanded)
            TextButton(
              onPressed: () => setState(() => _expanded = true),
              child: const Text('Tambah makna baru ke kata ini'),
            )
          else ...[
            TextField(
              decoration: const InputDecoration(labelText: 'Part of speech (POS)'),
              onChanged: (value) => setState(() => _draft = _draft.copyWith(pos: value, translation: null)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _draft.isGenerating
                        ? 'Membuat terjemahan...'
                        : (_draft.translation ?? 'Belum ada terjemahan'),
                    style: AppTextStyles.body,
                  ),
                ),
                TextButton(
                  onPressed: _draft.pos.trim().isEmpty || _draft.isGenerating ? null : _generate,
                  child: const Text('Buat Terjemahan'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            FilledButton(
              onPressed: _draft.pos.trim().isEmpty || _draft.translation == null || controllerState.isLoading
                  ? null
                  : _submit,
              child: controllerState.isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan makna baru'),
            ),
            if (controllerState.hasError)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Gagal menyimpan makna baru. Coba lagi.',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The full new-word form: level, topics, one-or-more meanings, submit.
class _NewWordForm extends StatelessWidget {
  const _NewWordForm({
    required this.cefrLevel,
    required this.onCefrLevelChanged,
    required this.selectedTopics,
    required this.topicsAsync,
    required this.onToggleTopic,
    required this.newTopicController,
    required this.isAddingTopic,
    required this.topicError,
    required this.onAddTopic,
    required this.meanings,
    required this.onMeaningPosChanged,
    required this.onGenerateTranslation,
    required this.onAddMeaningRow,
    required this.onRemoveMeaningRow,
    required this.canSubmit,
    required this.isSubmitting,
    required this.onSubmit,
    required this.errorMessage,
  });

  final String cefrLevel;
  final ValueChanged<String> onCefrLevelChanged;
  final List<String> selectedTopics;
  final AsyncValue<List<Topic>> topicsAsync;
  final ValueChanged<String> onToggleTopic;
  final TextEditingController newTopicController;
  final bool isAddingTopic;
  final String? topicError;
  final VoidCallback onAddTopic;
  final List<MeaningDraft> meanings;
  final void Function(int index, String pos) onMeaningPosChanged;
  final void Function(int index) onGenerateTranslation;
  final VoidCallback onAddMeaningRow;
  final void Function(int index) onRemoveMeaningRow;
  final bool canSubmit;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Level CEFR', style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final level in kCefrLevels)
              ChoiceChip(
                label: Text(level),
                selected: level == cefrLevel,
                selectedColor: AppColors.primary,
                labelStyle: AppTextStyles.badgeLabel.copyWith(
                  color: level == cefrLevel ? Colors.white : Colors.black87,
                ),
                onSelected: (_) => onCefrLevelChanged(level),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Text('Topik', style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.xs),
        topicsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text(
            'Gagal memuat daftar topik.',
            style: TextStyle(color: AppColors.error),
          ),
          data: (topics) => Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final topic in topics)
                FilterChip(
                  label: Text(topic.name),
                  selected: selectedTopics.contains(topic.name),
                  onSelected: (_) => onToggleTopic(topic.name),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: newTopicController,
                decoration: const InputDecoration(labelText: 'Tambah topik baru'),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              onPressed: isAddingTopic ? null : onAddTopic,
              icon: isAddingTopic
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
            ),
          ],
        ),
        if (topicError != null)
          Text(topicError!, style: const TextStyle(color: AppColors.error)),
        const SizedBox(height: AppSpacing.md),
        const Text('Makna', style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < meanings.length; i++)
          _MeaningRow(
            index: i,
            draft: meanings[i],
            isPrimary: i == 0,
            canRemove: meanings.length > 1,
            onPosChanged: (pos) => onMeaningPosChanged(i, pos),
            onGenerate: () => onGenerateTranslation(i),
            onRemove: () => onRemoveMeaningRow(i),
          ),
        TextButton(onPressed: onAddMeaningRow, child: const Text('+ Tambah makna lain')),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: canSubmit ? onSubmit : null,
          child: isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Simpan Kata'),
        ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(errorMessage!, style: const TextStyle(color: AppColors.error)),
          ),
      ],
    );
  }
}

class _MeaningRow extends StatelessWidget {
  const _MeaningRow({
    required this.index,
    required this.draft,
    required this.isPrimary,
    required this.canRemove,
    required this.onPosChanged,
    required this.onGenerate,
    required this.onRemove,
  });

  final int index;
  final MeaningDraft draft;
  final bool isPrimary;
  final bool canRemove;
  final ValueChanged<String> onPosChanged;
  final VoidCallback onGenerate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.disabled),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPrimary)
                const Text('Makna utama', style: AppTextStyles.badgeLabel)
              else
                Text('Makna ${index + 1}', style: AppTextStyles.badgeLabel),
              const Spacer(),
              if (canRemove)
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onRemove),
            ],
          ),
          TextField(
            decoration: const InputDecoration(labelText: 'Part of speech (POS)'),
            controller: TextEditingController(text: draft.pos)
              ..selection = TextSelection.collapsed(offset: draft.pos.length),
            onChanged: onPosChanged,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  draft.isGenerating
                      ? 'Membuat terjemahan...'
                      : (draft.translation ?? 'Belum ada terjemahan'),
                  style: AppTextStyles.body,
                ),
              ),
              TextButton(
                onPressed: draft.pos.trim().isEmpty || draft.isGenerating ? null : onGenerate,
                child: const Text('Buat Terjemahan'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
