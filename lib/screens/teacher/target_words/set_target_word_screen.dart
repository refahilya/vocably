import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../providers/teacher_target_word_providers.dart';
import '../../../providers/vocab_bundle_providers.dart';
import '../../../theme/theme.dart';
import '../../../utils/cefr_levels.dart';
import '../../../utils/target_word_constants.dart';

/// Full-screen flow for setting new target words (`SPEC.md` §4.1, `DESIGN_REFERENCE.md` §5.4).
class SetTargetWordScreen extends ConsumerStatefulWidget {
  const SetTargetWordScreen({super.key, required this.profile});

  final AppUser profile;

  @override
  ConsumerState<SetTargetWordScreen> createState() =>
      _SetTargetWordScreenState();
}

class _SetTargetWordScreenState extends ConsumerState<SetTargetWordScreen> {
  String _selectedLevel = kCefrLevels.first;
  final Set<String> _selectedWords = {};
  String _searchQuery = '';
  final _searchController = TextEditingController();

  DateTime _startDate = DateTime.now();
  bool _noEndDate = true;
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  bool get _isDateValid {
    if (_noEndDate) return true;
    final startDay = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    final endDay = DateTime(_endDate.year, _endDate.month, _endDate.day);
    return !endDay.isBefore(startDay);
  }

  bool get _canSubmit {
    return _selectedWords.isNotEmpty && _isDateValid;
  }

  Future<void> _submitTargetWordSet() async {
    if (!_canSubmit) return;

    final startAt = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      0,
      0,
      0,
    );

    final DateTime endAt;
    if (_noEndDate) {
      endAt = kNoEndDate.toDate();
    } else {
      endAt = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        23,
        59,
        59,
        999,
      );
    }

    final controller = ref.read(setTargetWordControllerProvider.notifier);
    await controller.createTargetWordSet(
      teacherId: widget.profile.uid,
      wordIds: _selectedWords.toList(),
      cefrLevel: _selectedLevel,
      startAt: startAt,
      endAt: endAt,
    );

    if (!mounted) return;
    final state = ref.read(setTargetWordControllerProvider);
    if (!state.hasError) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target kata berhasil disimpan.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vocabAsync = ref.watch(vocabLevelProvider(_selectedLevel));
    final controllerState = ref.watch(setTargetWordControllerProvider);
    final isSubmitting = controllerState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Set Target Baru')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step 1: CEFR Level
                  const Text(
                    '1. Pilih Level CEFR',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final level in kCefrLevels) ...[
                          ChoiceChip(
                            label: Text(level),
                            selected: _selectedLevel == level,
                            onSelected: (selected) {
                              if (selected && _selectedLevel != level) {
                                setState(() {
                                  _selectedLevel = level;
                                  _selectedWords.clear();
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              }
                            },
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Step 2: Select Words
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '2. Pilih Kata Target',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedWords.length} kata dipilih',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
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
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Words chip selector
                  vocabAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, _) => const Text(
                      'Gagal memuat kosakata level ini.',
                      style: TextStyle(color: Colors.red),
                    ),
                    data: (entries) {
                      final filtered = entries.where((e) {
                        if (_searchQuery.isEmpty) return true;
                        return e.word.toLowerCase().contains(_searchQuery);
                      }).toList();

                      if (filtered.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'Belum ada kata di level $_selectedLevel.'
                                : 'Tidak ada kata yang cocok dengan "$_searchQuery".',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final entry in filtered)
                                FilterChip(
                                  label: Text(entry.word),
                                  selected: _selectedWords.contains(entry.word),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedWords.add(entry.word);
                                      } else {
                                        _selectedWords.remove(entry.word);
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Step 3: Date range
                  const Text(
                    '3. Tentukan Rentang Waktu Target',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Card(
                    elevation: 0,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Start Date
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tanggal Mulai:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(_startDate),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              OutlinedButton.icon(
                                onPressed: _pickStartDate,
                                icon: const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                ),
                                label: const Text('Ubah'),
                              ),
                            ],
                          ),
                          const Divider(height: AppSpacing.lg),

                          // No End Date Toggle
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Tanpa batas akhir'),
                            subtitle: const Text(
                              'Target tetap aktif sampai diubah',
                            ),
                            value: _noEndDate,
                            onChanged: (val) {
                              setState(() {
                                _noEndDate = val ?? true;
                              });
                            },
                          ),

                          // End Date Picker (if not no-end-date)
                          if (!_noEndDate) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tanggal Selesai:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(_endDate),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                OutlinedButton.icon(
                                  onPressed: _pickEndDate,
                                  icon: const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                  ),
                                  label: const Text('Ubah'),
                                ),
                              ],
                            ),
                            if (!_isDateValid) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Tanggal selesai tidak boleh sebelum tanggal mulai.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (controllerState.hasError) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        'Gagal menyimpan target kata. Periksa koneksi lalu coba lagi.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Bottom CTA
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (!_canSubmit || isSubmitting)
                    ? null
                    : _submitTargetWordSet,
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan Target Kata'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
