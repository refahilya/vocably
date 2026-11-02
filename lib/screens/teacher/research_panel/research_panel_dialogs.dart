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

/// Authorizing the pretest or posttest. The posttest needs the researcher's
/// attestation that treatment session 4 is finished (the app does not track
/// sessions); a band from the Placement Test needs the K2 acknowledgement.
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
      if (stage == PanelStage.postTest) 'Sesi treatment ke-4 sudah selesai untuk ${who ?? 'peserta ini'}.',
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
