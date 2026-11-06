import 'package:flutter/material.dart';

import '../../../models/research_panel.dart';
import '../../../theme/theme.dart';

/// Confirmation with optional statements the researcher must tick first
/// (the action stays disabled until every one is ticked).
Future<bool> showPanelConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  List<String> checks = const [],
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _ConfirmDialog(title: title, body: body, confirmLabel: confirmLabel, checks: checks),
  );
  return ok ?? false;
}

/// Authorizing the pretest or posttest. The posttest is offered only once
/// all four official treatment sessions are recorded, and still needs the
/// researcher's attestation (attendance and supervision are not visible to
/// the app); a band from the Placement Test needs the K2 acknowledgement.
Future<bool> showAuthorizeDialog(
  BuildContext context, {
  required PanelStage stage,
  required int count,
  required bool bandFromPlacement,
  String? who,
}) {
  final target = who ?? '$count peserta yang siap';
  return showPanelConfirmDialog(
    context,
    title: 'Izinkan ${stage.label}?',
    body: '${stage.label} diizinkan untuk $target. Siswa dapat mengerjakannya selama tahap ini dibuka.',
    confirmLabel: count == 1 ? 'Izinkan' : 'Izinkan $count peserta',
    checks: [
      if (stage == PanelStage.postTest)
        'Sesi treatment ke-4 sudah selesai untuk ${who ?? 'peserta ini'}, sesuai daftar hadir dan catatan saya.',
      if (bandFromPlacement)
        'Saya memahami band berasal dari Placement Test (aturan K2 pilihan peneliti, belum divalidasi ahli).',
    ],
  );
}

class OpenStageChoice {
  const OpenStageChoice(this.duration);

  /// `null` = open until closed from the panel.
  final Duration? duration;
}

/// How long to open a stage: until closed, or a fixed time from now.
Future<OpenStageChoice?> showOpenStageDialog(BuildContext context, PanelStage stage) =>
    showDialog<OpenStageChoice>(context: context, builder: (_) => _OpenStageDialog(stage: stage));

/// The researcher's choice when opening an official treatment session.
class OpenTreatmentChoice {
  const OpenTreatmentChoice({required this.studentIds, required this.duration});

  final List<String> studentIds;
  final Duration duration;
}

/// Opening an official treatment session (`DATA_MODEL.md` §6e): the
/// session's five words, the students present (all ticked by default; for a
/// make-up the one student), how long it stays open, and the supervision
/// statement the researcher must tick. [latestClose] limits the window (the
/// make-up deadline).
Future<OpenTreatmentChoice?> showOpenTreatmentDialog(
  BuildContext context, {
  required String title,
  required String intro,
  required List<String> words,
  required List<(String, String)> candidates,
  required String confirmLabel,
  required String statement,
  DateTime? latestClose,
}) => showDialog<OpenTreatmentChoice>(
  context: context,
  builder: (_) => _OpenTreatmentDialog(
    title: title,
    intro: intro,
    words: words,
    candidates: candidates,
    confirmLabel: confirmLabel,
    statement: statement,
    latestClose: latestClose,
  ),
);

class _OpenTreatmentDialog extends StatefulWidget {
  const _OpenTreatmentDialog({
    required this.title,
    required this.intro,
    required this.words,
    required this.candidates,
    required this.confirmLabel,
    required this.statement,
    required this.latestClose,
  });

  final String title;
  final String intro;
  final List<String> words;

  /// (uid, label).
  final List<(String, String)> candidates;
  final String confirmLabel;
  final String statement;
  final DateTime? latestClose;

  @override
  State<_OpenTreatmentDialog> createState() => _OpenTreatmentDialogState();
}

class _OpenTreatmentDialogState extends State<_OpenTreatmentDialog> {
  late final Set<String> _present = {for (final c in widget.candidates) c.$1};
  int _duration = 0;
  bool _supervised = false;

  bool _fits(Duration d) {
    final latest = widget.latestClose;
    return latest == null || !DateTime.now().add(d).isAfter(latest);
  }

  @override
  Widget build(BuildContext context) {
    final durations = [for (final d in kTreatmentWindowChoices) if (_fits(d)) d];
    final duration = durations.isEmpty ? null : durations[_duration.clamp(0, durations.length - 1)];
    final ready = _present.isNotEmpty && _supervised && duration != null;
    final single = widget.candidates.length == 1;
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.intro, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.sm),
              Text('Kata sesi ini: ${widget.words.join(', ')}', style: AppTextStyles.bodyStrong),
              const SizedBox(height: AppSpacing.smd),
              if (!single) ...[
                Text('Hadir di kelas (${_present.length} dari ${widget.candidates.length})', style: AppTextStyles.caption),
                for (final c in widget.candidates)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _present.contains(c.$1),
                    onChanged: (v) => setState(() => v == true ? _present.add(c.$1) : _present.remove(c.$1)),
                    title: Text(c.$2, style: AppTextStyles.body),
                  ),
                const SizedBox(height: AppSpacing.sm),
              ] else ...[
                Text('Siswa: ${widget.candidates.single.$2}', style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (durations.isEmpty)
                const Text('Batas waktu susulan sudah terlalu dekat untuk membuka sesi.', style: AppTextStyles.body)
              else
                RadioGroup<int>(
                  groupValue: _duration.clamp(0, durations.length - 1),
                  onChanged: (v) => setState(() => _duration = v ?? 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < durations.length; i++)
                        RadioListTile<int>(
                          contentPadding: EdgeInsets.zero,
                          value: i,
                          title: Text('Tutup otomatis setelah ${durations[i].inMinutes} menit'),
                        ),
                    ],
                  ),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _supervised,
                onChanged: (v) => setState(() => _supervised = v ?? false),
                title: Text(widget.statement, style: AppTextStyles.body),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        FilledButton(
          onPressed: ready
              ? () => Navigator.of(context).pop(
                  OpenTreatmentChoice(
                    studentIds: [for (final c in widget.candidates) if (_present.contains(c.$1)) c.$1],
                    duration: duration,
                  ),
                )
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.title, required this.body, required this.confirmLabel, required this.checks});

  final String title;
  final String body;
  final String confirmLabel;
  final List<String> checks;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  late final _ticked = List<bool>.filled(widget.checks.length, false);

  @override
  Widget build(BuildContext context) {
    final ready = _ticked.every((t) => t);
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.body, style: AppTextStyles.body),
              for (var i = 0; i < widget.checks.length; i++)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _ticked[i],
                  onChanged: (v) => setState(() => _ticked[i] = v ?? false),
                  title: Text(widget.checks[i], style: AppTextStyles.body),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
        FilledButton(
          onPressed: ready ? () => Navigator.of(context).pop(true) : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _OpenStageDialog extends StatefulWidget {
  const _OpenStageDialog({required this.stage});

  final PanelStage stage;

  @override
  State<_OpenStageDialog> createState() => _OpenStageDialogState();
}

class _OpenStageDialogState extends State<_OpenStageDialog> {
  static const _choices = <(String, Duration?)>[
    ('Sampai saya tutup', null),
    ('60 menit', Duration(minutes: 60)),
    ('90 menit', Duration(minutes: 90)),
    ('120 menit', Duration(minutes: 120)),
  ];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Buka ${widget.stage.label}?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: RadioGroup<int>(
            groupValue: _selected,
            onChanged: (v) => setState(() => _selected = v ?? 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Peserta yang sudah diizinkan bisa mulai mengerjakan begitu tahap ini dibuka.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < _choices.length; i++)
                  RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,
                    value: i,
                    title: Text(i == 0 ? _choices[i].$1 : 'Tutup otomatis setelah ${_choices[i].$1}'),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(OpenStageChoice(_choices[_selected].$2)),
          child: Text('Buka ${widget.stage.label}'),
        ),
      ],
    );
  }
}
