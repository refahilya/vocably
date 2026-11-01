import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../providers/teacher_target_word_providers.dart';
import '../../../providers/vocab_bundle_providers.dart';
import '../../../theme/theme.dart';
import '../../../utils/cefr_levels.dart';
import '../../../utils/target_word_constants.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/app_layout.dart';
import '../../../widgets/cefr_level_selector.dart';

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

    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;

    final wordSteps = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Step 1: CEFR Level
        const Text('1. Pilih Level CEFR', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.sm),
        CefrLevelSelector(
          selected: _selectedLevel,
          onSelected: (level) {
            if (_selectedLevel != level) {
              setState(() {
                _selectedLevel = level;
                _selectedWords.clear();
                _searchQuery = '';
                _searchController.clear();
              });
            }
          },
        ),
        const SizedBox(height: AppSpacing.lg),

        // Step 2: Select Words
        AppSectionHeader(
          title: '2. Pilih Kata Target',
          trailing: AppBadge(
            text: '${_selectedWords.length} kata dipilih',
            tone: AppTone.info,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
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
          onChanged: (val) {
            setState(() {
              _searchQuery = val.trim().toLowerCase();
            });
          },
        ),
        const SizedBox(height: AppSpacing.sm),

        // Words chip selector
        vocabAsync.when(
          loading: () => const AppLoading(),
          error: (error, _) => const AppNotice(
            text: 'Gagal memuat kosakata level ini.',
            tone: AppTone.error,
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
                  style: AppTextStyles.bodyMuted,
                ),
              );
            }

            return AppSheet(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: isWide ? 440 : 240),
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: double.infinity,
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
                ),
              ),
            );
          },
        ),
      ],
    );

    final dateStep = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Step 3: Date range
        const Text(
          '3. Tentukan Rentang Waktu Target',
          style: AppTextStyles.sectionTitle,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSheet(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Start Date
              _DateRow(
                label: 'Tanggal Mulai:',
                value: _formatDate(_startDate),
                onPick: _pickStartDate,
              ),
              const Divider(height: AppSpacing.lg),

              // No End Date Toggle
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tanpa batas akhir'),
                subtitle: const Text('Target tetap aktif sampai diubah'),
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
                _DateRow(
                  label: 'Tanggal Selesai:',
                  value: _formatDate(_endDate),
                  onPick: _pickEndDate,
                ),
                if (!_isDateValid) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tanggal selesai tidak boleh sebelum tanggal mulai.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        if (controllerState.hasError) ...[
          const SizedBox(height: AppSpacing.smd),
          const AppNotice(
            text: 'Gagal menyimpan target kata. Periksa koneksi lalu coba lagi.',
            tone: AppTone.error,
          ),
        ],
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Set Target Baru')),
      body: Column(
        children: [
          Expanded(
            child: AppScrollPage(
              maxWidth: AppContentWidth.page,
              child: AppTwoPane(
                sideWidth: 360,
                primary: wordSteps,
                side: dateStep,
              ),
            ),
          ),
          // Bottom CTA
          AppBottomBar(
            maxWidth: AppContentWidth.page,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: isWide ? 360 : double.infinity,
                child: FilledButton(
                  onPressed: (!_canSubmit || isSubmitting)
                      ? null
                      : _submitTargetWordSet,
                  child: isSubmitting
                      ? const AppButtonSpinner()
                      : const Text('Simpan Target Kata'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled date with its "Ubah" button; wraps on very narrow phones.
class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final String value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppTextStyles.caption),
            Text(value, style: AppTextStyles.bodyStrong),
          ],
        ),
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.calendar_today, size: 16),
          label: const Text('Ubah'),
        ),
      ],
    );
  }
}
