import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/app_user.dart';
import '../../../models/research_panel.dart';
import '../../../models/research_participant.dart';
import '../../../models/research_treatment.dart';
import '../../../providers/research_panel_providers.dart';
import '../../../theme/theme.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/app_layout.dart';
import 'research_panel_dialogs.dart';

/// Researcher Panel ("Panel Riset", `SPEC.md` §4.3, `DESIGN_REFERENCE.md`
/// §5.9): the single researcher operator opens and closes test stages,
/// authorizes participants, follows their progress and handles technical
/// interruptions — without the command line. It reads like a class
/// register: the stages first, then the treatment sessions per band
/// (`DATA_MODEL.md` §6e), then one row per participant.
///
/// Only shown to the active operator (`researchOperators/{uid}`); every
/// action is re-checked by the security rules. It never shows answers,
/// scores or keys — only counts and status.
class ResearchPanelScreen extends ConsumerWidget {
  const ResearchPanelScreen({super.key, required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOperator = ref.watch(researchOperatorProvider(profile.uid));
    return switch (isOperator) {
      AsyncData(value: false) || AsyncError() => const AppStateMessage(
        icon: Icons.lock_outline,
        title: 'Panel Riset hanya untuk peneliti.',
        body: 'Akun ini belum terdaftar sebagai peneliti.',
      ),
      AsyncData(value: true) => _PanelBody(profile: profile),
      _ => const AppLoading(),
    };
  }
}

class _PanelBody extends ConsumerStatefulWidget {
  const _PanelBody({required this.profile});

  final AppUser profile;

  @override
  ConsumerState<_PanelBody> createState() => _PanelBodyState();
}

enum _RowFilter { all, action, working }

class _PanelBodyState extends ConsumerState<_PanelBody> {
  String _query = '';
  _RowFilter _filter = _RowFilter.all;

  ResearchPanelController get _controller =>
      ref.read(researchPanelControllerProvider(widget.profile.uid).notifier);

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(researchPanelDataProvider);
    final action = ref.watch(researchPanelControllerProvider(widget.profile.uid));
    return switch (dataAsync) {
      AsyncData(:final value) => _content(context, value, action),
      AsyncError() => AppErrorState(
        message: 'Data panel tidak dapat dimuat.',
        onRetry: () => ref.invalidate(researchPanelDataProvider),
      ),
      _ => const AppLoading(label: 'Memuat data peserta…'),
    };
  }

  List<PanelRow> _visibleRows(ResearchPanelData data) {
    final q = _query.trim().toLowerCase();
    return data.rows.where((row) {
      if (q.isNotEmpty &&
          !row.name.toLowerCase().contains(q) &&
          !row.participant.researchId.toLowerCase().contains(q)) {
        return false;
      }
      return switch (_filter) {
        _RowFilter.all => true,
        _RowFilter.action => row.cells.values.any((c) => c.hasAction) || row.treatment.makeupOffer != null,
        _RowFilter.working => row.cells.values.any(
          (c) => c.kind == PanelCellKind.inProgress || c.kind == PanelCellKind.placementInProgress,
        ),
      };
    }).toList();
  }

  Widget _content(BuildContext context, ResearchPanelData data, PanelActionState action) {
    final rows = _visibleRows(data);
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;
    return AppScrollPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(
            title: 'Panel Riset',
            subtitle: _studyLine(data),
            titleStyle: AppTextStyles.pageTitle,
          ),
          const SizedBox(height: AppSpacing.md),
          if (!data.study.active) ...[
            AppNotice(
              tone: AppTone.warning,
              text: data.study.exists
                  ? 'Studi tidak aktif, jadi tahap tes tidak bisa dibuka dari panel. '
                        'Status studi diatur lewat alat riset.'
                  : 'Studi belum disiapkan. Siapkan dulu lewat alat riset (README tools/research).',
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (action.notice case final notice?) ...[
            AppNotice(
              tone: notice.isError ? AppTone.error : AppTone.success,
              text: notice.text,
              action: IconButton(
                tooltip: 'Tutup pesan',
                icon: const Icon(Icons.close, size: 18),
                onPressed: _controller.dismissNotice,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const Text('Tahap tes', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          _StageSheet(
            data: data,
            action: action,
            onOpen: (stage) => _openStage(context, stage),
            onClose: (stage) => _closeStage(context, stage),
            onAuthorizeAll: (stage) => _authorizeAll(context, data, stage),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(title: 'Sesi treatment', subtitle: _treatmentLine(data)),
          const SizedBox(height: AppSpacing.sm),
          _TreatmentSheet(
            data: data,
            action: action,
            onOpen: (band, session, opening) => _openTreatment(context, data, band, session, opening),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(
            title: 'Peserta',
            subtitle: data.rows.isEmpty ? null : '${rows.length} dari ${data.rows.length} ditampilkan',
          ),
          const SizedBox(height: AppSpacing.sm),
          if (data.rows.isEmpty)
            const AppNotice(
              tone: AppTone.neutral,
              icon: Icons.group_outlined,
              text: 'Belum ada peserta. Daftarkan siswa lewat alat riset (perintah enrol), '
                  'lalu mereka muncul di sini.',
            )
          else ...[
            _RegisterTools(
              filter: _filter,
              onQuery: (q) => setState(() => _query = q),
              onFilter: (f) => setState(() => _filter = f),
            ),
            const SizedBox(height: AppSpacing.smd),
            if (rows.isEmpty)
              const AppNotice(tone: AppTone.neutral, text: 'Tidak ada peserta yang cocok dengan pencarian ini.')
            else
              _Register(
                rows: rows,
                wide: wide,
                busyKey: action.busyKey,
                onAction: (row, stage) => _cellAction(context, row, stage),
                onMakeup: (row) => _openMakeup(context, data, row),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const Text('Riwayat tindakan', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          _AuditList(data: data),
        ],
      ),
    );
  }

  String _studyLine(ResearchPanelData data) {
    final status = !data.study.exists
        ? 'Studi belum disiapkan'
        : data.study.active
        ? 'Studi aktif'
        : 'Studi tidak aktif';
    return '$status, ${data.rows.length} peserta';
  }

  String _treatmentLine(ResearchPanelData data) {
    final plan = data.study.treatmentPlanVersion;
    if (plan == null) return 'Rencana treatment belum disiapkan';
    return 'Rencana $plan, 4 sesi × 5 kata per band. Susulan satu kali per siswa, paling lambat '
        '${data.study.makeupDeadlineDays} hari setelah sesinya.';
  }

  String _who(PanelRow row) => row.name.isEmpty ? row.participant.researchId : '${row.name} (${row.participant.researchId})';

  Future<void> _openTreatment(BuildContext context, ResearchPanelData data, String band, int session, int opening) async {
    final plan = data.treatmentBands[band]?.plan;
    if (plan == null) return;
    final candidates = data.treatmentCandidates(band, session);
    if (candidates.isEmpty) return;
    final choice = await showOpenTreatmentDialog(
      context,
      title: opening == 1 ? 'Buka sesi $session band $band?' : 'Buka ulang sesi $session band $band?',
      intro: opening == 1
          ? 'Hanya siswa yang dicentang yang bisa memulai sesi ini, selama sesi dibuka. Siswa yang tidak hadir '
                'bisa mengikuti susulan satu kali.'
          : 'Pembukaan ulang untuk siswa yang terlambat atau terkendala teknis hari ini. Dicatat sebagai pembukaan '
                'ke-$opening.',
      words: plan.sessions[session] ?? const [],
      candidates: [for (final r in candidates) (r.uid, _who(r))],
      confirmLabel: opening == 1 ? 'Buka sesi $session' : 'Buka ulang sesi $session',
      statement: 'Siswa yang dicentang hadir di kelas dan diawasi selama sesi ini.',
    );
    if (choice == null) return;
    await _controller.openTreatment(
      plan: plan,
      session: session,
      opening: opening,
      studentIds: choice.studentIds,
      duration: choice.duration,
    );
  }

  Future<void> _openMakeup(BuildContext context, ResearchPanelData data, PanelRow row) async {
    final band = row.participant.band;
    final plan = band == null ? null : data.treatmentBands[band]?.plan;
    final session = row.treatment.makeupOffer;
    if (plan == null || session == null) return;
    final choice = await showOpenTreatmentDialog(
      context,
      title: 'Buka susulan sesi $session untuk ${_who(row)}?',
      intro: 'Setiap siswa hanya mendapat satu kali susulan. Setelah dibuka, susulan siswa ini sudah terpakai, '
          'walaupun tidak diselesaikan.',
      words: plan.sessions[session] ?? const [],
      candidates: [(row.uid, _who(row))],
      confirmLabel: 'Buka susulan',
      statement: 'Siswa ini mengerjakan susulan di bawah pengawasan saya.',
      latestClose: row.treatment.makeupDeadline,
    );
    if (choice == null) return;
    await _controller.openMakeup(plan: plan, row: row, session: session, duration: choice.duration);
  }

  Future<void> _openStage(BuildContext context, PanelStage stage) async {
    final duration = await showOpenStageDialog(context, stage);
    if (duration == null) return;
    await _controller.openStage(stage, duration: duration.duration);
  }

  Future<void> _closeStage(BuildContext context, PanelStage stage) async {
    final ok = await showPanelConfirmDialog(
      context,
      title: 'Tutup ${stage.label}?',
      body: 'Siswa yang sedang mengerjakan tidak bisa lanjut. Jawaban yang sudah tersimpan tetap ada '
          'dan bisa dilanjutkan bila tahap ini dibuka lagi.',
      confirmLabel: 'Tutup ${stage.label}',
    );
    if (ok) await _controller.closeStage(stage);
  }

  Future<void> _authorizeAll(BuildContext context, ResearchPanelData data, PanelStage stage) async {
    final rows = data.authorizable(stage);
    if (rows.isEmpty) return;
    final ok = await showAuthorizeDialog(
      context,
      stage: stage,
      count: rows.length,
      bandFromPlacement: rows.any((r) => r.participant.bandFromPlacement),
    );
    if (ok) await _controller.authorizeAll(rows, stage);
  }

  Future<void> _cellAction(BuildContext context, PanelRow row, PanelStage stage) async {
    final cell = row.cells[stage]!;
    final who = row.name.isEmpty ? row.participant.researchId : '${row.name} (${row.participant.researchId})';
    if (cell.canAuthorize) {
      final ok = await showAuthorizeDialog(
        context,
        stage: stage,
        count: 1,
        who: who,
        bandFromPlacement: row.participant.bandFromPlacement,
      );
      if (ok) await _controller.authorize(row, stage);
    } else if (cell.canVoidAndRetake || cell.canRetake) {
      final ok = await showPanelConfirmDialog(
        context,
        title: 'Ulang ${stage.label} untuk $who?',
        body: cell.canVoidAndRetake
            ? 'Percobaan ke-${cell.attemptNumber} dibatalkan karena gangguan teknis, lalu siswa '
                  'mengerjakan percobaan ke-${cell.attemptNumber + 1} dari awal. Jawaban percobaan '
                  'lama tetap disimpan, tetapi tidak dipakai. Gunakan hanya untuk gangguan teknis.'
            : 'Percobaan ke-${cell.attemptNumber} sudah dibatalkan. Siswa akan mengerjakan '
                  'percobaan ke-${cell.attemptNumber + 1} dari awal.',
        confirmLabel: cell.canVoidAndRetake ? 'Batalkan dan ulang' : 'Izinkan ulang',
        checks: cell.canVoidAndRetake ? const ['Ini gangguan teknis (perangkat atau koneksi), bukan alasan lain.'] : const [],
      );
      if (ok) await _controller.retake(row, stage, voidCurrent: cell.canVoidAndRetake);
    }
  }
}

String _time(DateTime t) => DateFormat('HH.mm').format(t);
String _dateTime(DateTime t) => DateFormat('d/M HH.mm').format(t);

/// The three stages, each with its window and the controls. The stage that
/// is open now carries the highlighter — the one loud element of the page.
class _StageSheet extends StatelessWidget {
  const _StageSheet({
    required this.data,
    required this.action,
    required this.onOpen,
    required this.onClose,
    required this.onAuthorizeAll,
  });

  final ResearchPanelData data;
  final PanelActionState action;
  final void Function(PanelStage) onOpen;
  final void Function(PanelStage) onClose;
  final void Function(PanelStage) onAuthorizeAll;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return AppSheet(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final stage in PanelStage.values) ...[
            if (stage != PanelStage.placement) const Divider(height: 1, color: AppColors.line),
            _StageRow(
              stage: stage,
              data: data,
              open: data.study.stageOpen(stage, now),
              window: data.study.windows[stage],
              action: action,
              onOpen: () => onOpen(stage),
              onClose: () => onClose(stage),
              onAuthorizeAll: () => onAuthorizeAll(stage),
            ),
          ],
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.stage,
    required this.data,
    required this.open,
    required this.window,
    required this.action,
    required this.onOpen,
    required this.onClose,
    required this.onAuthorizeAll,
  });

  final PanelStage stage;
  final ResearchPanelData data;
  final bool open;
  final PanelWindow? window;
  final PanelActionState action;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onAuthorizeAll;

  String get _windowText {
    final w = window;
    if (w == null) return 'Belum pernah dibuka';
    if (open) {
      return w.openEnded
          ? 'Dibuka sejak ${_dateTime(w.openAt)}, sampai ditutup'
          : 'Dibuka sejak ${_dateTime(w.openAt)}, tutup otomatis ${_time(w.closeAt)}';
    }
    if (DateTime.now().isBefore(w.openAt)) return 'Dijadwalkan ${_dateTime(w.openAt)}';
    return 'Ditutup ${_dateTime(w.closeAt)}';
  }

  String get _summary {
    int n(PanelCellKind k) => data.count(stage, k);
    if (stage == PanelStage.placement) {
      final parts = [
        if (n(PanelCellKind.banded) > 0) '${n(PanelCellKind.banded)} sudah punya band',
        if (n(PanelCellKind.placementInProgress) > 0) '${n(PanelCellKind.placementInProgress)} mengerjakan',
        if (n(PanelCellKind.placementSubmitted) > 0) '${n(PanelCellKind.placementSubmitted)} menunggu penilaian',
        if (n(PanelCellKind.placementNotStarted) > 0) '${n(PanelCellKind.placementNotStarted)} belum mulai',
        if (n(PanelCellKind.excluded) > 0) '${n(PanelCellKind.excluded)} tidak ikut (C1)',
        if (n(PanelCellKind.needsResearcher) > 0) '${n(PanelCellKind.needsResearcher)} perlu peneliti',
      ];
      return parts.isEmpty ? 'Belum ada peserta' : parts.join(', ');
    }
    final parts = [
      if (n(PanelCellKind.completed) > 0) '${n(PanelCellKind.completed)} selesai',
      if (n(PanelCellKind.inProgress) > 0) '${n(PanelCellKind.inProgress)} mengerjakan',
      if (n(PanelCellKind.notStarted) > 0) '${n(PanelCellKind.notStarted)} belum mulai',
      if (n(PanelCellKind.notAuthorized) > 0) '${n(PanelCellKind.notAuthorized)} belum diizinkan',
      if (n(PanelCellKind.voided) > 0) '${n(PanelCellKind.voided)} dibatalkan',
      if (n(PanelCellKind.waitingForPreTest) > 0) '${n(PanelCellKind.waitingForPreTest)} menunggu Pre-Test',
      if (n(PanelCellKind.waitingForBand) > 0) '${n(PanelCellKind.waitingForBand)} menunggu band',
    ];
    return parts.isEmpty ? 'Belum ada peserta' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final busyHere = action.busyKey == 'stage:${stage.id}';
    final bulkHere = action.busyKey == 'bulk:${stage.id}';
    final authorizable = stage == PanelStage.placement ? 0 : data.authorizable(stage).length;
    final canToggle = data.study.active && !action.busy;
    final controls = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (authorizable > 0 || bulkHere)
          OutlinedButton(
            onPressed: action.busy ? null : onAuthorizeAll,
            child: bulkHere
                ? Text('Mengizinkan ${action.done}/${action.total}…')
                : Text('Izinkan $authorizable peserta'),
          ),
        open
            ? OutlinedButton(
                onPressed: canToggle ? onClose : null,
                child: busyHere ? const AppButtonSpinner(size: 18) : Text('Tutup ${stage.label}'),
              )
            : FilledButton(
                onPressed: canToggle ? onOpen : null,
                child: busyHere
                    ? const AppButtonSpinner(color: Colors.white, size: 18)
                    : Text('Buka ${stage.label}'),
              ),
      ],
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(child: Text(stage.label, style: AppTextStyles.wordRow)),
            if (open) ...[
              const SizedBox(width: AppSpacing.sm),
              const _Highlight(text: 'Sedang dibuka'),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(_windowText, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.xs),
        Text(_summary, style: AppTextStyles.bodyMuted),
      ],
    );
    return DecoratedBox(
      // The highlighter stripe: only on the stage that is open now.
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: open ? AppColors.marker : Colors.transparent, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md - 4, AppSpacing.smd, AppSpacing.md, AppSpacing.smd),
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 560
              ? Row(
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: AppSpacing.md),
                    controls,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [text, const SizedBox(height: AppSpacing.smd), controls],
                ),
        ),
      ),
    );
  }
}

/// Highlighter label (the stabilo): marks what is live right now.
class _Highlight extends StatelessWidget {
  const _Highlight({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.marker,
      borderRadius: BorderRadius.circular(AppRadius.small),
    ),
    child: Text(text, style: AppTextStyles.badgeLabel.copyWith(color: AppColors.primaryDeep)),
  );
}

class _RegisterTools extends StatelessWidget {
  const _RegisterTools({required this.filter, required this.onQuery, required this.onFilter});

  final _RowFilter filter;
  final ValueChanged<String> onQuery;
  final ValueChanged<_RowFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _RowFilter.all: 'Semua',
      _RowFilter.action: 'Bisa ditindak',
      _RowFilter.working: 'Sedang mengerjakan',
    };
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: TextField(
            onChanged: onQuery,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 20),
              hintText: 'Cari nama atau ID riset',
            ),
          ),
        ),
        for (final f in _RowFilter.values)
          ChoiceChip(
            label: Text(labels[f]!),
            selected: filter == f,
            onSelected: (_) => onFilter(f),
          ),
      ],
    );
  }
}

/// The participant register: a table on wide screens, one block per
/// participant on phones.
class _Register extends StatelessWidget {
  const _Register({
    required this.rows,
    required this.wide,
    required this.busyKey,
    required this.onAction,
    required this.onMakeup,
  });

  final List<PanelRow> rows;
  final bool wide;
  final String? busyKey;
  final void Function(PanelRow, PanelStage) onAction;
  final void Function(PanelRow) onMakeup;

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide) const _RegisterHeader(),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0 || wide) const Divider(height: 1, color: AppColors.line),
            wide
                ? _WideRow(row: rows[i], busyKey: busyKey, onAction: onAction, onMakeup: onMakeup)
                : _NarrowRow(row: rows[i], busyKey: busyKey, onAction: onAction, onMakeup: onMakeup),
          ],
        ],
      ),
    );
  }
}

const _nameFlex = 3;
const _cellFlex = 3;

class _RegisterHeader extends StatelessWidget {
  const _RegisterHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Expanded(flex: _nameFlex, child: Text('Peserta', style: AppTextStyles.caption)),
          for (final stage in PanelStage.values) ...[
            if (stage == PanelStage.postTest)
              const Expanded(flex: _cellFlex, child: Text('Treatment', style: AppTextStyles.caption)),
            Expanded(flex: _cellFlex, child: Text(stage.label, style: AppTextStyles.caption)),
          ],
        ],
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.row});

  final PanelRow row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.name.isEmpty ? 'Tanpa nama' : row.name,
          style: AppTextStyles.bodyStrong.copyWith(color: row.name.isEmpty ? AppColors.inkMuted : null),
        ),
        Text(row.participant.researchId, style: AppTextStyles.caption),
      ],
    );
  }
}

class _WideRow extends StatelessWidget {
  const _WideRow({required this.row, required this.busyKey, required this.onAction, required this.onMakeup});

  final PanelRow row;
  final String? busyKey;
  final void Function(PanelRow, PanelStage) onAction;
  final void Function(PanelRow) onMakeup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.smd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: _nameFlex, child: _Identity(row: row)),
          for (final stage in PanelStage.values) ...[
            if (stage == PanelStage.postTest)
              Expanded(
                flex: _cellFlex,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _TreatmentCellView(row: row, busyKey: busyKey, onMakeup: () => onMakeup(row)),
                ),
              ),
            Expanded(
              flex: _cellFlex,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _CellView(
                  cell: row.cells[stage]!,
                  stage: stage,
                  busy: busyKey == 'row:${row.uid}:${stage.id}',
                  disabled: busyKey != null,
                  onAction: () => onAction(row, stage),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NarrowRow extends StatelessWidget {
  const _NarrowRow({required this.row, required this.busyKey, required this.onAction, required this.onMakeup});

  final PanelRow row;
  final String? busyKey;
  final void Function(PanelRow, PanelStage) onAction;
  final void Function(PanelRow) onMakeup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Identity(row: row),
          const SizedBox(height: AppSpacing.sm),
          for (final stage in PanelStage.values) ...[
            if (stage == PanelStage.postTest)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 104, child: Text('Treatment', style: AppTextStyles.caption)),
                    Expanded(child: _TreatmentCellView(row: row, busyKey: busyKey, onMakeup: () => onMakeup(row))),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 104, child: Text(stage.label, style: AppTextStyles.caption)),
                  Expanded(
                    child: _CellView(
                      cell: row.cells[stage]!,
                      stage: stage,
                      busy: busyKey == 'row:${row.uid}:${stage.id}',
                      disabled: busyKey != null,
                      onAction: () => onAction(row, stage),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One stage cell: what the participant's state is, the count while
/// answering, and the one action the panel offers there (if any).
class _CellView extends StatelessWidget {
  const _CellView({
    required this.cell,
    required this.stage,
    required this.busy,
    required this.disabled,
    required this.onAction,
  });

  final PanelCell cell;
  final PanelStage stage;
  final bool busy;
  final bool disabled;
  final VoidCallback onAction;

  (String, AppTone) get _status => switch (cell.kind) {
    PanelCellKind.placementNotStarted => ('Belum mulai', AppTone.neutral),
    PanelCellKind.placementInProgress => ('Mengerjakan ${cell.answered}/${cell.total}', AppTone.info),
    PanelCellKind.placementSubmitted => ('Terkirim, menunggu penilaian', AppTone.info),
    PanelCellKind.banded => ('Band ${cell.band}', AppTone.success),
    PanelCellKind.excluded => ('Tidak ikut studi (hasil C1)', AppTone.neutral),
    PanelCellKind.needsResearcher => ('Perlu tindakan peneliti lewat alat riset', AppTone.warning),
    PanelCellKind.waitingForBand => ('Menunggu hasil Placement', AppTone.neutral),
    PanelCellKind.notEligible => ('Tidak ikut tahap ini', AppTone.neutral),
    PanelCellKind.notAuthorized => ('Belum diizinkan', AppTone.neutral),
    PanelCellKind.waitingForPreTest => ('Menunggu Pre-Test selesai', AppTone.neutral),
    PanelCellKind.waitingForTreatment => ('Menunggu 4 sesi treatment', AppTone.neutral),
    PanelCellKind.notStarted => (
      cell.attemptNumber > 1 ? 'Percobaan ke-${cell.attemptNumber}, belum mulai' : 'Diizinkan, belum mulai',
      AppTone.neutral,
    ),
    PanelCellKind.inProgress => (
      'Mengerjakan ${cell.answered}/${cell.total}${cell.attemptNumber > 1 ? ' (percobaan ke-${cell.attemptNumber})' : ''}',
      AppTone.info,
    ),
    PanelCellKind.completed => ('Selesai', AppTone.success),
    PanelCellKind.voided => ('Dibatalkan', AppTone.warning),
    PanelCellKind.unreadable => ('Data tidak terbaca', AppTone.error),
  };

  String? get _actionLabel => cell.canAuthorize
      ? 'Izinkan'
      : cell.canVoidAndRetake
      ? 'Ulang (gangguan teknis)'
      : cell.canRetake
      ? 'Izinkan ulang'
      : null;

  @override
  Widget build(BuildContext context) {
    final (text, tone) = _status;
    final label = _actionLabel;
    final working = cell.kind == PanelCellKind.inProgress || cell.kind == PanelCellKind.placementInProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: AppTextStyles.body.copyWith(
            color: tone == AppTone.neutral ? AppColors.inkMuted : tone.foreground,
            fontWeight: tone == AppTone.neutral ? null : FontWeight.w600,
          ),
        ),
        if (working && cell.total > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: cell.answered / cell.total,
              minHeight: 4,
              color: AppColors.primary,
              backgroundColor: AppColors.primaryTint,
              semanticsLabel: '${stage.label}: ${cell.answered} dari ${cell.total} terjawab',
            ),
          ),
        ],
        if (label != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                minimumSize: const Size(0, 36),
              ),
              onPressed: disabled ? null : onAction,
              child: busy ? const AppButtonSpinner(size: 16) : Text(label),
            ),
          ),
      ],
    );
  }
}

class _AuditList extends StatelessWidget {
  const _AuditList({required this.data});

  final ResearchPanelData data;

  String _describe(PanelAuditEntry e) {
    final who = () {
      final row = data.rows.where((r) => r.uid == e.targetUid).firstOrNull;
      if (row == null) return 'peserta';
      return row.name.isEmpty ? row.participant.researchId : '${row.name} (${row.participant.researchId})';
    }();
    final stage = e.stage?.label ?? 'tahap';
    return switch (e.action) {
      'open_stage' => 'Membuka $stage',
      'close_stage' => 'Menutup $stage',
      'authorize' => e.stage == PanelStage.postTest
          ? 'Mengizinkan $stage untuk $who, dengan konfirmasi sesi ke-4 selesai'
          : 'Mengizinkan $stage untuk $who',
      'void' => 'Membatalkan $stage percobaan ke-${e.attemptNumber} milik $who (gangguan teknis)',
      'retake' => 'Mengizinkan $who mengulang $stage (percobaan ke-${e.attemptNumber})',
      'open_treatment' => 'Membuka sesi treatment ${e.session} band ${e.band} untuk ${e.studentCount} siswa (hadir dan diawasi)',
      'open_makeup' => 'Membuka susulan sesi ${e.session} untuk $who (diawasi)',
      _ => 'Tindakan lain',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (data.audit.isEmpty) {
      return const AppNotice(
        tone: AppTone.neutral,
        icon: Icons.history,
        text: 'Belum ada tindakan dari panel. Setiap tindakan tercatat di sini.',
      );
    }
    return AppSheet(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < data.audit.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      data.audit[i].at == null ? 'baru saja' : _dateTime(data.audit[i].at!),
                      style: AppTextStyles.caption,
                    ),
                  ),
                  Expanded(child: Text(_describe(data.audit[i]), style: AppTextStyles.body)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The official treatment sessions per band (`DATA_MODEL.md` §6e): which
/// session is next, which is open now, and how many participants finished
/// each. A session that is open now carries the highlighter.
class _TreatmentSheet extends StatelessWidget {
  const _TreatmentSheet({required this.data, required this.action, required this.onOpen});

  final ResearchPanelData data;
  final PanelActionState action;

  /// (band, session, opening).
  final void Function(String, int, int) onOpen;

  @override
  Widget build(BuildContext context) {
    if (data.study.treatmentPlanVersion == null) {
      return const AppNotice(
        tone: AppTone.neutral,
        icon: Icons.event_note_outlined,
        text: 'Rencana treatment belum disiapkan. Jalankan seed-treatment lewat alat riset '
            '(README tools/research), lalu sesi bisa dibuka di sini.',
      );
    }
    final bands = data.treatmentBands.values.where((b) => data.rows.any((r) => r.participant.band == b.band)).toList();
    if (bands.isEmpty) {
      return const AppNotice(
        tone: AppTone.neutral,
        icon: Icons.group_outlined,
        text: 'Belum ada peserta dengan band. Sesi treatment dibuka per band setelah Placement Test.',
      );
    }
    return AppSheet(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < bands.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.line),
            _TreatmentBandRow(band: bands[i], data: data, action: action, onOpen: onOpen),
          ],
        ],
      ),
    );
  }
}

class _TreatmentBandRow extends StatelessWidget {
  const _TreatmentBandRow({required this.band, required this.data, required this.action, required this.onOpen});

  final PanelTreatmentBand band;
  final ResearchPanelData data;
  final PanelActionState action;
  final void Function(String, int, int) onOpen;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final rows = data.rows.where((r) => r.participant.band == band.band).toList();
    final open = band.openNow(now);
    final next = band.nextSession;
    final reopen = band.reopenable(now);
    final busy = action.busyKey == 'treat:${band.band}';
    final planReady = band.plan != null;

    String sessionText(int n) {
      final first = band.regular(n);
      if (first == null) return 'Sesi $n belum dibuka';
      final done = rows.where((r) => r.treatment.done.contains(n)).length;
      final openSet = open.where((s) => s.info.session == n).firstOrNull;
      if (openSet != null) return 'Sesi $n dibuka sampai ${_time(openSet.endAt)}, $done/${rows.length} selesai';
      return 'Sesi $n: $done/${rows.length} selesai';
    }

    final candidatesNext = next == null ? 0 : data.treatmentCandidates(band.band, next).length;
    final candidatesReopen = reopen == null ? 0 : data.treatmentCandidates(band.band, reopen).length;
    final canAct = data.study.active && planReady && !action.busy;
    final controls = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (reopen != null && candidatesReopen > 0)
          OutlinedButton(
            onPressed: canAct ? () => onOpen(band.band, reopen, band.openings(reopen) + 1) : null,
            child: Text('Buka ulang sesi $reopen'),
          ),
        if (next != null)
          FilledButton(
            onPressed: canAct && candidatesNext > 0 && open.isEmpty ? () => onOpen(band.band, next, 1) : null,
            child: busy ? const AppButtonSpinner(color: Colors.white, size: 18) : Text('Buka sesi $next'),
          ),
      ],
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(child: Text('Band ${band.band}', style: AppTextStyles.wordRow)),
            if (open.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              _Highlight(text: 'Sesi ${open.first.info.session} dibuka'),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          !planReady
              ? 'Rencana band ini belum tersedia'
              : next == null
              ? 'Keempat sesi sudah dibuka'
              : candidatesNext == 0
              ? 'Sesi berikutnya: $next (belum ada peserta yang siap — Pre-Test belum selesai)'
              : 'Sesi berikutnya: $next, $candidatesNext peserta siap',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text([for (var n = 1; n <= kTreatmentSessions; n++) sessionText(n)].join(' · '), style: AppTextStyles.bodyMuted),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: open.isNotEmpty ? AppColors.marker : Colors.transparent, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md - 4, AppSpacing.smd, AppSpacing.md, AppSpacing.smd),
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 560
              ? Row(
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: AppSpacing.md),
                    controls,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [text, const SizedBox(height: AppSpacing.smd), controls],
                ),
        ),
      ),
    );
  }
}

/// One participant's treatment: sessions recorded, the make-up, and the
/// make-up action when a missed session can still be made up.
class _TreatmentCellView extends StatelessWidget {
  const _TreatmentCellView({required this.row, required this.busyKey, required this.onMakeup});

  final PanelRow row;
  final String? busyKey;
  final VoidCallback onMakeup;

  @override
  Widget build(BuildContext context) {
    final t = row.treatment;
    final done = (t.done.toList()..sort());
    final (text, tone) = t.complete
        ? ('4/4 sesi selesai', AppTone.success)
        : !t.eligible && done.isEmpty
        ? (
            row.participant.status == ResearchParticipantStatus.awaitingPlacement
                ? 'Menunggu band'
                : row.participant.canTakeResearchStages
                ? 'Menunggu Pre-Test selesai'
                : 'Tidak ikut tahap ini',
            AppTone.neutral,
          )
        : t.openNow.isNotEmpty
        ? ('Sesi ${t.openNow.first} dibuka · ${done.length}/4 selesai', AppTone.info)
        : (done.isEmpty ? '0/4 selesai' : '${done.length}/4 selesai (sesi ${done.join(', ')})', AppTone.neutral);
    final offer = t.makeupOffer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: AppTextStyles.body.copyWith(
            color: tone == AppTone.neutral ? AppColors.inkMuted : tone.foreground,
            fontWeight: tone == AppTone.neutral ? null : FontWeight.w600,
          ),
        ),
        if (t.makeupUsed) Text('Susulan dipakai: sesi ${t.makeupSession}', style: AppTextStyles.caption),
        if (offer != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                minimumSize: const Size(0, 36),
              ),
              onPressed: busyKey != null ? null : onMakeup,
              child: busyKey == 'makeup:${row.uid}' ? const AppButtonSpinner(size: 16) : Text('Susulan sesi $offer'),
            ),
          ),
      ],
    );
  }
}
