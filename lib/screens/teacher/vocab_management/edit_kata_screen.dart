import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../models/vocab_bundle_entry.dart';
import '../../../providers/vocab_bundle_providers.dart';
import '../../../providers/vocab_management_providers.dart';
import '../../../theme/theme.dart';
import '../../../utils/cefr_levels.dart';

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
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CEFR Choice Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final level in kCefrLevels) ...[
                      ChoiceChip(
                        label: Text(level),
                        selected: _selectedLevel == level,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedLevel = level;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                  ],
                ),
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
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Word list
        Expanded(
          child: vocabAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Gagal memuat kosakata.'),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(vocabLevelProvider(_selectedLevel)),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            ),
            data: (entries) {
              final filtered = entries.where((e) {
                if (_searchQuery.isEmpty) return true;
                return e.word.toLowerCase().contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'Belum ada kosakata di level $_selectedLevel.'
                          : 'Tidak ada kosakata yang cocok dengan "$_searchQuery".',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  final translation = entry.primaryMeaning.translation ?? '—';
                  final pos = entry.primaryMeaning.pos;
                  final topicsText = entry.topics.isEmpty
                      ? 'Tanpa topik'
                      : entry.topics.join(', ');

                  return ListTile(
                    title: Row(
                      children: [
                        Text(
                          entry.word,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '($pos)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(translation),
                        const SizedBox(height: 2),
                        Text(
                          'Topik: $topicsText',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _openEditModal(entry),
                  );
                },
              );
            },
          ),
        ),
      ],
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
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Topik Kata',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: AppSpacing.xs),

            // Read-only word info
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.entry.word,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Chip(
                          label: Text(widget.entry.cefrLevel),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Makna:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    for (final meaning in widget.entry.meanings)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '• (${meaning.pos}) ${meaning.translation ?? "—"}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Editable topics section
            const Text(
              'Topik Kata (bisa pilih lebih dari satu)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),

            topicsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => const Text(
                'Gagal memuat daftar topik.',
                style: TextStyle(color: Colors.red),
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
            const SizedBox(height: AppSpacing.sm),

            // Add new topic inline
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTopicController,
                    decoration: InputDecoration(
                      labelText: 'Tambah topik baru',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      errorText: _topicError,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton.tonal(
                  onPressed: _isAddingTopic ? null : _addNewTopic,
                  child: _isAddingTopic
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('+ Tambah'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            if (controllerState.hasError) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Gagal memperbarui topik. Periksa koneksi lalu coba lagi.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],

            // Save button
            FilledButton(
              onPressed: (!_hasChanges || isSaving) ? null : _saveTopics,
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Simpan Perubahan Topik'),
            ),
          ],
        ),
      ),
    );
  }
}
