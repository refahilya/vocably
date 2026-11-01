import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/placement_attempt.dart';
import '../../../models/placement_instrument.dart';
import '../../../models/placement_status.dart';
import '../../../providers/placement_test_providers.dart';
import '../../../theme/theme.dart';
import '../../../utils/story_markers.dart';
import '../../../widgets/assessment_widgets.dart';
import 'placement_instructions.dart';

/// The Placement Test (`SPEC.md` §3.1, `DESIGN_REFERENCE.md` §5.2, spec
/// PT-V1.1 §3–§4): instructions, then 50 items one per screen ("Soal x dari
/// 50", band labels never shown), each an English sentence with the target
/// word bold and underlined and options A–D plus E "Saya tidak tahu". Answers are saved
/// on every choice and may change until "Kirim jawaban"; a summary lists
/// unanswered items; submission needs all 50 and a confirmation.
///
/// After submission only the level is shown — never band scores, totals,
/// correctness, the key or any quality signal. "App hidden" lifecycle
/// signals are recorded on the attempt and never acted on.
class PlacementTestScreen extends ConsumerStatefulWidget {
  const PlacementTestScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<PlacementTestScreen> createState() => _PlacementTestScreenState();
}

class _PlacementTestScreenState extends ConsumerState<PlacementTestScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // On the web, `hidden` follows the page's visibilitychange (tab switch,
    // minimised window). Window blur (`inactive`) is not counted: it also
    // fires for the address bar, devtools or system dialogs.
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(placementTestControllerProvider(widget.uid).notifier).recordHidden(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = placementTestControllerProvider(widget.uid);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final busy = switch (state) {
      PlacementTestReady(:final starting) => starting,
      PlacementTestAnswering(:final busy) => busy,
      PlacementTestScoring(:final error) => error == null,
      _ => false,
    };

    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Tes Penempatan')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: switch (state) {
                PlacementTestLoading() => const AssessmentBusy(label: 'Memuat tes…'),
                PlacementTestLoadFailed() => AssessmentMessage(
                  icon: Icons.wifi_off,
                  title: 'Gagal memuat tes',
                  body: 'Periksa koneksi internet, lalu coba lagi.',
                  actionLabel: 'Coba lagi',
                  onAction: controller.reload,
                ),
                PlacementTestInvalid() => const AssessmentMessage(
                  icon: Icons.error_outline,
                  title: 'Tes tidak dapat dilanjutkan',
                  body: 'Data tes tidak sesuai. Hubungi peneliti.',
                ),
                PlacementTestBlocked(:final reason, :final lastResult) => _blocked(reason, lastResult, controller),
                PlacementTestReady(:final starting, :final error) => _Intro(
                  buttonLabel: 'Mulai',
                  busy: starting,
                  errorText: switch (error) {
                    PlacementActionError.network => 'Tes belum dapat dimulai. Periksa koneksi internet, lalu coba lagi.',
                    PlacementActionError.refused => 'Tes belum dapat dimulai. Tunggu arahan pengawas.',
                    null => null,
                  },
                  onPressed: controller.start,
                ),
                PlacementTestPaused() => AssessmentMessage(
                  icon: Icons.lock_clock,
                  title: 'Tes sedang ditutup',
                  body: 'Tes sedang ditutup. Jawabanmu tersimpan. Tunggu arahan pengawas.',
                  actionLabel: 'Muat ulang',
                  onAction: controller.reload,
                ),
                PlacementTestAnswering(showIntro: true) => _Intro(
                  buttonLabel: 'Lanjutkan',
                  busy: false,
                  onPressed: controller.dismissIntro,
                ),
                final PlacementTestAnswering s when s.reviewing => _Summary(
                  state: s,
                  onGoTo: controller.goTo,
                  onSubmit: () => _confirmSubmit(context, controller),
                ),
                final PlacementTestAnswering s => _ItemView(
                  state: s,
                  onSelect: controller.select,
                  onPrevious: controller.previous,
                  onNext: controller.next,
                ),
                PlacementTestScoring(error: null) => const AssessmentBusy(label: 'Mengirim jawaban…'),
                PlacementTestScoring(:final error) => AssessmentMessage(
                  icon: Icons.cloud_done_outlined,
                  title: 'Jawabanmu sudah terkirim',
                  body: error == PlacementActionError.network
                      ? 'Jawabanmu sudah tersimpan, tetapi hasilnya belum dapat diproses. Periksa koneksi internet, lalu coba lagi.'
                      : 'Jawabanmu sudah tersimpan, tetapi hasilnya belum dapat diproses. Beri tahu pengawas atau peneliti.',
                  actionLabel: 'Coba lagi',
                  onAction: controller.retryScoring,
                ),
                final PlacementTestResult s => _ResultView(state: s, onRetake: controller.startRetake),
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSubmit(BuildContext context, PlacementTestController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kirim jawaban?'),
        content: const Text('Setelah dikirim, jawaban tidak dapat diubah. Kirim sekarang?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Periksa lagi')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Kirim')),
        ],
      ),
    );
    if (confirmed == true) await controller.submit();
  }

  Widget _blocked(PlacementBlock reason, PlacementAttemptRecord? lastResult, PlacementTestController controller) {
    final (icon, title, body) = switch (reason) {
      PlacementBlock.notConfigured => (Icons.hourglass_empty, 'Belum tersedia', 'Tes penempatan belum tersedia.'),
      PlacementBlock.researchClosed ||
      PlacementBlock.researchNotAuthorized => (Icons.lock_outline, 'Tes belum dibuka', 'Tes belum dibuka. Tunggu arahan pengawas.'),
      PlacementBlock.reviewPending => (
        Icons.hourglass_top,
        'Mohon tunggu',
        'Status tesmu sedang diperiksa peneliti. Hubungi peneliti bila ada pertanyaan.',
      ),
      PlacementBlock.voidedTechnical => (
        Icons.build_circle_outlined,
        'Tes dihentikan',
        'Percobaan tes ini dihentikan karena gangguan teknis. Peneliti akan membuka percobaan baru.',
      ),
      PlacementBlock.contactResearcher => (Icons.support_agent, 'Hubungi peneliti', 'Hubungi peneliti untuk langkah berikutnya.'),
      PlacementBlock.learningClosed => (Icons.lock_outline, 'Belum dibuka', 'Tes penempatan sedang tidak dibuka. Coba lagi nanti.'),
    };
    return AssessmentMessage(
      icon: icon,
      title: title,
      body: body,
      footer: lastResult?.result == null ? null : _LevelLine(level: lastResult!.result!.resultLevel),
      actionLabel: 'Muat ulang',
      onAction: controller.reload,
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.buttonLabel, required this.busy, required this.onPressed, this.errorText});

  final String buttonLabel;
  final bool busy;
  final VoidCallback onPressed;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.infoBackground,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(kPlacementInstructionsTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: AppSpacing.sm),
                const Text(kPlacementInstructionsIntro, style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.md),
                const Text(kPlacementInstructionsHeading, style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.xs),
                for (var i = 0; i < kPlacementInstructions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text('${i + 1}. ${kPlacementInstructions[i]}', style: AppTextStyles.body),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (errorText != null) ...[
            AssessmentErrorBanner(text: errorText!),
            const SizedBox(height: AppSpacing.md),
          ],
          FilledButton(
            onPressed: busy ? null : onPressed,
            child: busy ? const AssessmentButtonSpinner() : Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _Sentence extends StatelessWidget {
  const _Sentence({required this.item});

  final PlacementItem item;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: AppTextStyles.assessmentSentence,
        children: [
          for (final segment in item.segments)
            switch (segment) {
              PlainStorySegment(:final text) => TextSpan(text: text),
              MarkedStorySegment(:final surfaceForm) => TextSpan(
                text: surfaceForm,
                style: AppTextStyles.assessmentTarget,
              ),
            },
        ],
      ),
    );
  }
}

class _ItemView extends StatelessWidget {
  const _ItemView({required this.state, required this.onSelect, required this.onPrevious, required this.onNext});

  final PlacementTestAnswering state;
  final void Function(String answer) onSelect;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final item = state.currentItem;
    final saved = state.attempt.answers[item.id];
    final saving = state.savingItemId == item.id;
    final labels = [
      for (final option in item.options) (option.id, '${option.id}. ${option.text}'),
      (kPlacementDontKnowId, '$kPlacementDontKnowId. $kPlacementDontKnowText'),
    ];
    return SingleChildScrollView(
      key: ValueKey('placement-item-${item.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Soal ${state.index + 1} dari ${state.items.length}', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sm),
          _Sentence(item: item),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            container: true,
            label: 'Pilihan jawaban',
            child: Column(
              children: [
                for (final (id, label) in labels)
                  AssessmentOptionTile(
                    key: ValueKey('placement-option-$id'),
                    label: label,
                    selected: saved == id,
                    enabled: !state.busy,
                    onTap: () => onSelect(id),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 20,
            child: Text(
              saving ? 'Menyimpan…' : (saved != null ? 'Tersimpan' : ''),
              style: AppTextStyles.caption,
            ),
          ),
          if (state.error != null) ...[
            const AssessmentErrorBanner(
              text: 'Jawaban belum tersimpan. Periksa koneksi internet, lalu pilih lagi.',
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.index == 0 || state.busy ? null : onPrevious,
                  child: const Text('Sebelumnya'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: state.busy ? null : onNext,
                  child: Text(state.index == state.items.length - 1 ? 'Ringkasan' : 'Berikutnya'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state, required this.onGoTo, required this.onSubmit});

  final PlacementTestAnswering state;
  final void Function(int index) onGoTo;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final missing = state.unansweredNumbers;
    return SingleChildScrollView(
      key: const ValueKey('placement-summary'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Ringkasan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            missing.isEmpty
                ? 'Semua soal sudah dijawab. Ketuk nomor soal untuk memeriksa jawabanmu.'
                : 'Masih ada soal yang belum dijawab: nomor ${missing.join(', ')}. Jawab semuanya (pilih E jika tidak tahu) sebelum mengirim.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (var i = 0; i < state.items.length; i++)
                SizedBox(
                  width: 44,
                  child: OutlinedButton(
                    key: ValueKey('placement-summary-${i + 1}'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: state.attempt.answers.containsKey(state.items[i].id) ? AppColors.infoBackground : null,
                    ),
                    onPressed: state.busy ? null : () => onGoTo(i),
                    child: Text('${i + 1}'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (state.error != null) ...[
            const AssessmentErrorBanner(text: 'Jawaban belum terkirim. Periksa koneksi internet, lalu coba lagi.'),
            const SizedBox(height: AppSpacing.md),
          ],
          FilledButton(
            onPressed: missing.isEmpty && !state.busy ? onSubmit : null,
            child: state.submitting ? const AssessmentButtonSpinner() : const Text('Kirim jawaban'),
          ),
        ],
      ),
    );
  }
}

class _LevelLine extends StatelessWidget {
  const _LevelLine({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: AppTextStyles.body,
        children: [
          const TextSpan(text: 'Level kamu: '),
          TextSpan(text: level, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.state, required this.onRetake});

  final PlacementTestResult state;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final result = state.attempt.result!;
    final research = state.attempt.context == PlacementContext.research;
    final retakeAt = state.retakeAvailableAt;
    return AssessmentMessage(
      icon: Icons.check_circle_outline,
      title: state.justFinished ? 'Terima kasih. Jawabanmu sudah tersimpan.' : 'Hasil tes penempatan',
      body: research
          ? 'Level ini dipakai untuk menyesuaikan kata yang kamu pelajari. Peneliti akan menjelaskan langkah berikutnya.'
          : 'Level ini dipakai untuk menyesuaikan kata yang kamu pelajari.',
      footer: Column(
        children: [
          _LevelLine(level: result.resultLevel),
          if (retakeAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Kamu bisa mengulang tes ini mulai ${DateFormat('d/M/yyyy HH:mm').format(retakeAt)}.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
          if (state.nextLearningAttempt != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetake, child: const Text('Ulangi tes')),
          ],
        ],
      ),
    );
  }
}
