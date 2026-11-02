import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/research_panel.dart';
import '../services/research_assessment_service.dart';
import '../services/research_panel_service.dart';

part 'research_panel_providers.g.dart';

@Riverpod(keepAlive: true)
ResearchPanelService researchPanelService(Ref ref) => ResearchPanelService();

/// Whether [uid] is the active researcher operator (`DATA_MODEL.md` §6d).
/// Live: revoking the record in the tooling removes the panel. This only
/// decides what the app shows; every panel write is re-checked by the rules.
@riverpod
Stream<bool> researchOperator(Ref ref, String uid) =>
    ref.watch(researchPanelServiceProvider).watchOperator(uid);

/// Live panel data: study windows, participants, roster names, progress
/// mirrors and the latest audit entries, combined once every source has
/// delivered its first value.
@riverpod
Stream<ResearchPanelData> researchPanelData(Ref ref) {
  final service = ref.watch(researchPanelServiceProvider);
  final controller = StreamController<ResearchPanelData>();
  PanelStudy? study;
  List<PanelParticipant>? participants;
  List<PanelRosterEntry>? roster;
  List<PanelProgress>? progress;
  List<PanelAuditEntry>? audit;

  void emit() {
    if (study == null || participants == null || roster == null || progress == null || audit == null) return;
    controller.add(
      ResearchPanelData.combine(
        study: study!,
        participants: participants!,
        roster: roster!,
        progress: progress!,
        audit: audit!,
      ),
    );
  }

  final subscriptions = <StreamSubscription<Object?>>[
    service.watchStudy().listen((v) {
      study = v;
      emit();
    }, onError: controller.addError),
    service.watchParticipants().listen((v) {
      participants = v;
      emit();
    }, onError: controller.addError),
    service.watchRoster().listen((v) {
      roster = v;
      emit();
    }, onError: controller.addError),
    service.watchProgress().listen((v) {
      progress = v;
      emit();
    }, onError: controller.addError),
    service.watchAudit().listen((v) {
      audit = v;
      emit();
    }, onError: controller.addError),
  ];
  ref.onDispose(() {
    for (final s in subscriptions) {
      s.cancel();
    }
    controller.close();
  });
  return controller.stream;
}

/// Outcome of the last panel action, shown as a notice.
class PanelNotice {
  const PanelNotice(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

class PanelActionState {
  const PanelActionState({this.busyKey, this.done = 0, this.total = 0, this.notice});

  /// What is being written now (`stage:<id>`, `row:<uid>:<stage>`,
  /// `bulk:<stage>`), or `null`.
  final String? busyKey;

  /// Progress of a bulk authorization.
  final int done;
  final int total;
  final PanelNotice? notice;

  bool get busy => busyKey != null;
}

String _failureText(ResearchServiceException error) => switch (error.kind) {
  ResearchFailureKind.permissionDenied =>
    'Ditolak server. Datanya mungkin sudah berubah, dan daftar di bawah sudah diperbarui.',
  ResearchFailureKind.unavailable || ResearchFailureKind.timeout =>
    'Tidak tersambung ke server. Periksa koneksi, lalu coba lagi.',
  _ => 'Tindakan gagal. Coba lagi.',
};

/// Runs Researcher Panel actions one at a time for the signed-in operator.
@riverpod
class ResearchPanelController extends _$ResearchPanelController {
  @override
  PanelActionState build(String operatorUid) => const PanelActionState();

  ResearchPanelService get _service => ref.read(researchPanelServiceProvider);

  void _set(PanelActionState next) {
    if (ref.mounted) state = next;
  }

  void dismissNotice() => _set(PanelActionState(busyKey: state.busyKey, done: state.done, total: state.total));

  Future<void> _run(String key, Future<void> Function() action, String success) async {
    if (state.busy) return;
    _set(PanelActionState(busyKey: key));
    try {
      await action();
      _set(PanelActionState(notice: PanelNotice(success)));
    } on ResearchServiceException catch (error) {
      _set(PanelActionState(notice: PanelNotice(_failureText(error), isError: true)));
    } catch (_) {
      _set(const PanelActionState(notice: PanelNotice('Tindakan gagal. Coba lagi.', isError: true)));
    }
  }

  Future<void> openStage(PanelStage stage, {Duration? duration}) => _run(
    'stage:${stage.id}',
    () => _service.openStage(operatorUid: operatorUid, stage: stage, duration: duration),
    '${stage.label} dibuka.',
  );

  Future<void> closeStage(PanelStage stage) => _run(
    'stage:${stage.id}',
    () => _service.closeStage(operatorUid: operatorUid, stage: stage),
    '${stage.label} ditutup.',
  );

  Future<void> authorize(PanelRow row, PanelStage stage) => _run(
    'row:${row.uid}:${stage.id}',
    () => _service.authorize(operatorUid: operatorUid, row: row, stage: stage),
    '${stage.label} diizinkan untuk ${row.participant.researchId}.',
  );

  /// Technical interruption: void the unfinished attempt (if [voidCurrent])
  /// and authorize the next attempt.
  Future<void> retake(PanelRow row, PanelStage stage, {required bool voidCurrent}) => _run(
    'row:${row.uid}:${stage.id}',
    () => _service.retake(operatorUid: operatorUid, row: row, stage: stage, voidCurrent: voidCurrent),
    '${row.participant.researchId} dapat mengulang ${stage.label} dari awal.',
  );

  /// Authorizes [rows] one batch each (the rules' per-request read limit
  /// rules out one large batch). A refusal for one participant does not stop
  /// the others.
  Future<void> authorizeAll(List<PanelRow> rows, PanelStage stage) async {
    if (state.busy || rows.isEmpty) return;
    final key = 'bulk:${stage.id}';
    var ok = 0;
    var failed = 0;
    ResearchServiceException? lastError;
    _set(PanelActionState(busyKey: key, total: rows.length));
    for (final row in rows) {
      try {
        await _service.authorize(operatorUid: operatorUid, row: row, stage: stage);
        ok++;
      } on ResearchServiceException catch (error) {
        failed++;
        lastError = error;
      } catch (_) {
        failed++;
      }
      _set(PanelActionState(busyKey: key, done: ok + failed, total: rows.length));
    }
    _set(
      PanelActionState(
        notice: failed == 0
            ? PanelNotice('${stage.label} diizinkan untuk $ok peserta.')
            : PanelNotice(
                '${stage.label} diizinkan untuk $ok peserta; $failed gagal. '
                '${lastError == null ? 'Coba lagi.' : _failureText(lastError)}',
                isError: true,
              ),
      ),
    );
  }
}
