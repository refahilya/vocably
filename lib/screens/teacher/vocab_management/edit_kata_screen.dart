import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../models/vocab_bundle_entry.dart';
import '../../../providers/vocab_bundle_providers.dart';
import '../../../providers/vocab_management_providers.dart';
import '../../../theme/theme.dart';
import '../../../utils/cefr_levels.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/app_layout.dart';
import '../../../widgets/cefr_level_selector.dart';

/// Guru "Edit Kata" screen (`SPEC.md` §4.1, `DESIGN_REFERENCE.md` §5.4).
/// Allows searching and filtering vocabulary, and editing ONLY `topics`
/// of an existing word.
class EditKataScreen extends ConsumerStatefulWidget {
  const EditKataScreen({super.key, required this.profile});

  final AppUser profile;

  @override
  ConsumerState<EditKataScreen> createState() => _EditKataScreenState();
}

class _EditKataScreenState extends ConsumerState<EditKataScreen> {
  String _selectedLevel = kCefrLevels.first;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openEditModal(VocabBundleEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (modalContext) =>
          _EditWordSheet(entry: entry, teacherId: widget.profile.uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vocabAsync = ref.watch(vocabLevelProvider(_selectedLevel));

    return Column(
      children: [
        // Level selector & search bar
        AppContent(
          maxWidth: AppContentWidth.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CefrLevelSelector(
                selected: _selectedLevel,
                onSelected: (level) => setState(() => _selectedLevel = level),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Search field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari kata di level $_selectedLevel...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Hapus pencarian',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
              ),
              const SizedBox(height: AppSpacing.smd),
            ],
          ),
        ),
        // Word list
        Expanded(
          child: vocabAsync.when(
            loading: () => const AppLoading(),
            error: (error, _) => AppErrorState(
              message: 'Gagal memuat kosakata.',
              onRetry: () => ref.invalidate(vocabLevelProvider(_selectedLevel)),
            ),
            data: (entries) {
              final filtered = entries.where((e) {
                if (_searchQuery.isEmpty) return true;
                return e.word.toLowerCase().contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return AppStateMessage(
                  icon: Icons.search_off,
                  title: _searchQuery.isEmpty
                      ? 'Belum ada kosakata di level $_selectedLevel.'
                      : 'Tidak ada kosakata yang cocok dengan "$_searchQuery".',
                );
              }

              return AppContent(
                maxWidth: AppContentWidth.page,
                child: AppResponsiveList(
                  itemCount: filtered.length,
                  minItemWidth: 340,
                  gap: AppSpacing.sm,
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    return _EditableWordTile(
                      entry: entry,
                      onTap: () => _openEditModal(entry),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EditableWordTile extends StatelessWidget {
  const _EditableWordTile({required this.entry, required this.onTap});

  final VocabBundleEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final translation = entry.primaryMeaning.translation ?? '—';
    final pos = entry.primaryMeaning.pos;
    final topicsText = entry.topics.isEmpty
        ? 'Tanpa topik'
        : entry.topics.join(', ');

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.smd,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.xs,
                      children: [
                        Text(entry.word, style: AppTextStyles.wordRow),
                        Text('($pos)', style: AppTextStyles.caption),
                      ],
                    ),
                    Text(translation, style: AppTextStyles.body),
                    const SizedBox(height: 2),
                    Text('Topik: $topicsText', style: AppTextStyles.caption),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.edit_outlined, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal bottom sheet for editing a word's topics.
class _EditWordSheet extends ConsumerStatefulWidget {
  const _EditWordSheet({required this.entry, required this.teacherId});

  final VocabBundleEntry entry;
  final String teacherId;

  @override
  ConsumerState<_EditWordSheet> createState() => _EditWordSheetState();
}

class _EditWordSheetState extends ConsumerState<_EditWordSheet> {
  late List<String> _selectedTopics;
  final _newTopicController = TextEditingController();
  bool _isAddingTopic = false;
  String? _topicError;

  @override
  void initState() {
    super.initState();
    _selectedTopics = List<String>.from(widget.entry.topics);
  }

  @override
  void dispose() {
    _newTopicController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final original = widget.entry.topics.toSet();
    final current = _selectedTopics.toSet();
    if (original.length != current.length) return true;
    return !original.containsAll(current);
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
          .read(editKataControllerProvider.notifier)
          .addNewTopic(name: name, teacherId: widget.teacherId);
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
        _topicError = 'Gagal menambahkan topik baru.';
      });
    }
  }

  Future<void> _saveTopics() async {
    final controller = ref.read(editKataControllerProvider.notifier);
    await controller.updateWordTopics(
      normalizedWord: widget.entry.word,
      topics: _selectedTopics,
    );

    if (!mounted) return;
    final state = ref.read(editKataControllerProvider);
    if (!state.hasError) {
      ref.invalidate(vocabLevelProvider(widget.entry.cefrLevel));
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Topik untuk "${widget.entry.word}" berhasil diperbarui.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(editKataControllerProvider);
    final topicsAsync = ref.watch(topicsListProvider);
    final isSaving = controllerState.isLoading;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Text('Edit Topik Kata', style: AppTextStyles.statusTitle),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Read-only word info
            AppSheet(
              color: AppColors.surfaceAlt,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.entry.word,
                          style: AppTextStyles.wordTitle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppBadge.solid(text: widget.entry.cefrLevel),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text('Makna:', style: AppTextStyles.caption),
                  for (final meaning in widget.entry.meanings)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '• (${meaning.pos}) ${meaning.translation ?? "—"}',
                        style: AppTextStyles.bodyMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Editable topics section
            const Text(
              'Topik Kata (bisa pilih lebih dari satu)',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.sm),

            topicsAsync.when(
              loading: () => const AppLoading(),
              error: (error, _) => const AppNotice(
                text: 'Gagal memuat daftar topik.',
                tone: AppTone.error,
              ),
              data: (topics) {
                return Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final topic in topics)
                      FilterChip(
                        label: Text(topic.name),
                        selected: _selectedTopics.contains(topic.name),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTopics.add(topic.name);
                            } else {
                              _selectedTopics.remove(topic.name);
                            }
                          });
                        },
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.smd),

            // Add new topic inline
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTopicController,
                    decoration: InputDecoration(
                      labelText: 'Tambah topik baru',
                      errorText: _topicError,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  onPressed: _isAddingTopic ? null : _addNewTopic,
                  child: _isAddingTopic
                      ? const AppButtonSpinner(size: 16)
                      : const Text('+ Tambah'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            if (controllerState.hasError) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppNotice(
                  text: 'Gagal memperbarui topik. Periksa koneksi lalu coba lagi.',
                  tone: AppTone.error,
                ),
              ),
            ],

            // Save button
            FilledButton(
              onPressed: (!_hasChanges || isSaving) ? null : _saveTopics,
              child: isSaving
                  ? const AppButtonSpinner()
                  : const Text('Simpan Perubahan Topik'),
            ),
          ],
        ),
      ),
    );
  }
}
