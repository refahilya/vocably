import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/app_user.dart';
import 'package:vocably/models/research_panel.dart';
import 'package:vocably/models/research_participant.dart';
import 'package:vocably/models/research_treatment.dart';
import 'package:vocably/providers/research_panel_providers.dart';
import 'package:vocably/screens/teacher/research_panel/research_panel_screen.dart';
import 'package:vocably/services/research_assessment_service.dart';
import 'package:vocably/theme/theme.dart';
import 'package:vocably/utils/role.dart';

import '../support/fake_research_panel_service.dart';

final _researcher = AppUser(uid: 'researcher-1', email: 'peneliti@example.test', name: 'Peneliti', role: Role.guru, createdAt: DateTime(2026));
final _teacher = AppUser(uid: 'teacher-2', email: 'guru@example.test', name: 'Guru', role: Role.guru, createdAt: DateTime(2026));

FakeResearchPanelService _classroom({Set<PanelStage> open = const {}}) => FakeResearchPanelService(
  study: activeStudy(open: open),
  plans: [panelPlan('A2'), panelPlan('B1'), panelPlan('B2')],
  // R-05 finished all four official sessions; R-04 has not finished the pretest.
  records: [panelRecord('s5', {1, 2, 3, 4})],
  participants: [
    panelParticipant('s1', researchId: 'R-01', status: ResearchParticipantStatus.awaitingPlacement),
    panelParticipant('s2', researchId: 'R-02', band: 'A2'),
    panelParticipant('s3', researchId: 'R-03', band: 'B2'),
    panelParticipant('s4', researchId: 'R-04', band: 'B1', pre: 1),
    panelParticipant('s5', researchId: 'R-05', band: 'B1', pre: 1),
  ],
  roster: const [
    PanelRosterEntry(uid: 's1', name: 'Ayu Lestari', researchId: 'R-01'),
    PanelRosterEntry(uid: 's2', name: 'Bima Saputra', researchId: 'R-02'),
    PanelRosterEntry(uid: 's3', name: 'Citra Dewi', researchId: 'R-03'),
    PanelRosterEntry(uid: 's4', name: 'Dimas Pratama', researchId: 'R-04'),
    PanelRosterEntry(uid: 's5', name: 'Eka Putri', researchId: 'R-05'),
  ],
  progress: [
    panelProgress('s1', PanelStage.placement, answered: 23),
    panelProgress('s4', PanelStage.preTest, answered: 7),
    panelProgress('s5', PanelStage.preTest, answered: 20, status: 'completed'),
  ],
);

Future<void> _pump(WidgetTester tester, FakeResearchPanelService service, {AppUser? user, Size size = const Size(1280, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [researchPanelServiceProvider.overrideWithValue(service)],
      child: MaterialApp(theme: AppTheme.themeData, home: Scaffold(body: ResearchPanelScreen(profile: user ?? _researcher))),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));

Future<void> _tapLast(WidgetTester tester, String label) async {
  await tester.ensureVisible(_button(label).last);
  await tester.tap(_button(label).last);
  await tester.pumpAndSettle();
}

/// The row of [researchId] in the wide register.
Finder _rowOf(String researchId) => find.ancestor(of: find.text(researchId), matching: find.byType(Row)).first;

void main() {
  testWidgets('an ordinary guru account sees no panel', (tester) async {
    await _pump(tester, _classroom(), user: _teacher);
    expect(find.text('Panel Riset hanya untuk peneliti.'), findsOneWidget);
    expect(find.text('Tahap tes'), findsNothing);
    expect(find.text('Bima Saputra'), findsNothing);
  });

  testWidgets('the operator sees the stages, every participant and their progress — counts only', (tester) async {
    await _pump(tester, _classroom(open: {PanelStage.preTest}));
    expect(find.text('Panel Riset'), findsOneWidget);
    expect(find.text('Studi aktif, 5 peserta'), findsOneWidget);
    expect(find.text('Sedang dibuka'), findsOneWidget);
    for (final name in ['Ayu Lestari', 'Bima Saputra', 'Citra Dewi', 'Dimas Pratama', 'Eka Putri']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Mengerjakan 23/50'), findsOneWidget);
    expect(find.text('Mengerjakan 7/20'), findsOneWidget);
    expect(find.text('Menunggu hasil Placement'), findsNWidgets(2));
    // Once in the register, once as the band's treatment row.
    expect(find.text('Band A2'), findsNWidgets(2));
    expect(find.text('4/4 sesi selesai'), findsOneWidget);
    expect(find.textContaining('1 selesai, 1 mengerjakan, 2 belum diizinkan'), findsOneWidget);
  });

  testWidgets('opens a stage for a fixed time, then closes it after confirming', (tester) async {
    final service = _classroom();
    await _pump(tester, service);
    await _tapLast(tester, 'Buka Pre-Test');
    expect(find.text('Buka Pre-Test?'), findsOneWidget);
    await tester.tap(find.text('Tutup otomatis setelah 90 menit'));
    await tester.pumpAndSettle();
    await _tapLast(tester, 'Buka Pre-Test');
    expect(service.calls, ['open:preTest:90']);
    expect(find.text('Pre-Test dibuka.'), findsOneWidget);
    expect(find.text('Sedang dibuka'), findsOneWidget);
    expect(find.textContaining('tutup otomatis'), findsOneWidget);

    await _tapLast(tester, 'Tutup Pre-Test');
    expect(find.text('Tutup Pre-Test?'), findsOneWidget);
    await _tapLast(tester, 'Tutup Pre-Test');
    expect(service.calls.last, 'close:preTest');
    expect(find.text('Sedang dibuka'), findsNothing);
  });

  testWidgets('authorizing everyone ready needs the placement acknowledgement', (tester) async {
    final service = _classroom();
    await _pump(tester, service);
    await _tapLast(tester, 'Izinkan 2 peserta');
    final confirm = tester.widget<FilledButton>(_button('Izinkan 2 peserta').last);
    expect(confirm.onPressed, isNull, reason: 'disabled until the acknowledgement is ticked');
    await tester.tap(find.textContaining('band berasal dari Placement Test'));
    await tester.pumpAndSettle();
    await _tapLast(tester, 'Izinkan 2 peserta');
    expect(service.calls, ['authorize:s2:preTest', 'authorize:s3:preTest']);
    expect(find.text('Pre-Test diizinkan untuk 2 peserta.'), findsOneWidget);
    expect(find.text('Izinkan 2 peserta'), findsNothing);
  });

  testWidgets('the posttest needs the session-4 attestation, for one participant', (tester) async {
    final service = _classroom();
    await _pump(tester, service);
    final row = _rowOf('R-05');
    await tester.ensureVisible(row);
    final authorize = find.descendant(of: row, matching: _button('Izinkan'));
    expect(authorize, findsOneWidget, reason: 'only R-05 has a completed pretest');
    await tester.tap(authorize);
    await tester.pumpAndSettle();
    expect(find.textContaining('Sesi treatment ke-4 sudah selesai'), findsOneWidget);
    await tester.tap(find.textContaining('Sesi treatment ke-4 sudah selesai'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(_button('Izinkan').last).onPressed, isNull, reason: 'both statements are required');
    await tester.tap(find.textContaining('band berasal dari Placement Test'));
    await tester.pumpAndSettle();
    await _tapLast(tester, 'Izinkan');
    expect(service.calls, ['authorize:s5:postTest']);
    expect(find.textContaining('dengan konfirmasi sesi ke-4 selesai'), findsOneWidget);
  });

  testWidgets('a technical interruption voids the attempt and allows attempt 2', (tester) async {
    final service = _classroom();
    await _pump(tester, service);
    await _tapLast(tester, 'Ulang (gangguan teknis)');
    expect(find.text('Ulang Pre-Test untuk Dimas Pratama (R-04)?'), findsOneWidget);
    await tester.tap(find.textContaining('Ini gangguan teknis'));
    await tester.pumpAndSettle();
    await _tapLast(tester, 'Batalkan dan ulang');
    expect(service.calls, ['retake:s4:preTest:void']);
    expect(find.text('Percobaan ke-2, belum mulai'), findsOneWidget);
    expect(find.textContaining('Membatalkan Pre-Test percobaan ke-1 milik Dimas Pratama (R-04)'), findsOneWidget);
  });

  testWidgets('a refused action is explained, and cancelling does nothing', (tester) async {
    final service = _classroom()..failNext = ResearchFailureKind.permissionDenied;
    await _pump(tester, service);
    await _tapLast(tester, 'Buka Placement Test');
    await _tapLast(tester, 'Batal');
    expect(service.calls, isEmpty);
    await _tapLast(tester, 'Buka Placement Test');
    await _tapLast(tester, 'Buka Placement Test');
    expect(find.textContaining('Ditolak server'), findsOneWidget);
    expect(service.calls, isEmpty);
  });

  testWidgets('search and the "Bisa ditindak" filter narrow the register', (tester) async {
    await _pump(tester, _classroom());
    await tester.enterText(find.byType(TextField), 'citra');
    await tester.pumpAndSettle();
    expect(find.text('Citra Dewi'), findsOneWidget);
    expect(find.text('Bima Saputra'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Bisa ditindak'));
    await tester.pumpAndSettle();
    expect(find.text('Ayu Lestari'), findsNothing, reason: 'nothing to do while the placement is under way');
    expect(find.text('Bima Saputra'), findsOneWidget);
  });

  testWidgets('revoking the operator record removes the panel live', (tester) async {
    final service = _classroom();
    await _pump(tester, service);
    expect(find.text('Tahap tes'), findsOneWidget);
    service.operators = {};
    service.changed();
    await tester.pumpAndSettle();
    expect(find.text('Panel Riset hanya untuk peneliti.'), findsOneWidget);
  });

  testWidgets('without a study the panel explains it and offers no stage controls', (tester) async {
    final service = FakeResearchPanelService(study: PanelStudy.fromFirestore(null));
    await _pump(tester, service);
    expect(find.textContaining('Studi belum disiapkan'), findsWidgets);
    expect(tester.widget<FilledButton>(_button('Buka Pre-Test')).onPressed, isNull);
    expect(find.textContaining('Belum ada peserta'), findsWidgets);
  });

  testWidgets('on a phone every participant is one block with three stage lines', (tester) async {
    await _pump(tester, _classroom(open: {PanelStage.preTest}), size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Eka Putri'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Eka Putri'), findsOneWidget);
    expect(find.text('Placement Test'), findsWidgets);
  });
  group('treatment sessions', () {
    FakeResearchPanelService bandB1({List<PanelTreatmentSet> sets = const [], List<TreatmentRecord> records = const []}) => FakeResearchPanelService(
      study: activeStudy(),
      plans: [panelPlan('B1')],
      treatmentSets: sets,
      records: records,
      participants: [
        panelParticipant('t1', researchId: 'R-11', band: 'B1', pre: 1),
        panelParticipant('t2', researchId: 'R-12', band: 'B1', pre: 1),
        panelParticipant('t3', researchId: 'R-13', band: 'B1', pre: 1),
      ],
      roster: const [
        PanelRosterEntry(uid: 't1', name: 'Fajar', researchId: 'R-11'),
        PanelRosterEntry(uid: 't2', name: 'Gita', researchId: 'R-12'),
        PanelRosterEntry(uid: 't3', name: 'Hana', researchId: 'R-13'),
      ],
      progress: [for (final u in ['t1', 't2', 't3']) panelProgress(u, PanelStage.preTest, answered: 20, status: 'completed')],
    );

    testWidgets('opening session 1 for the students present needs the supervision statement', (tester) async {
      final service = bandB1();
      await _pump(tester, service);
      expect(find.text('Sesi berikutnya: 1, 3 peserta siap'), findsOneWidget);
      await _tapLast(tester, 'Buka sesi 1');
      expect(find.text('Buka sesi 1 band B1?'), findsOneWidget);
      expect(find.textContaining(planWords('B1', 1).join(', ')), findsOneWidget);
      // Gita is absent today.
      await tester.tap(find.text('Gita (R-12)'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(_button('Buka sesi 1').last).onPressed, isNull, reason: 'the supervision statement is required');
      await tester.tap(find.textContaining('hadir di kelas dan diawasi'));
      await tester.pumpAndSettle();
      await _tapLast(tester, 'Buka sesi 1');
      expect(service.calls, ['treat:B1:1:1:t1,t3:60']);
      expect(find.text('Sesi 1 band B1 dibuka untuk 2 siswa.'), findsOneWidget);
      expect(find.text('Sesi 1 dibuka'), findsOneWidget, reason: 'the open session carries the highlighter');
      expect(find.textContaining('Membuka sesi treatment 1 band B1 untuk 2 siswa'), findsOneWidget);
      expect(tester.widget<FilledButton>(_button('Buka sesi 2')).onPressed, isNull, reason: 'one session at a time');
    });

    testWidgets('a student who missed a closed session gets the one make-up, before the deadline', (tester) async {
      final now = DateTime.now();
      final service = bandB1(
        sets: [panelSet('B1', 1, students: const ['t1', 't3'], startAt: now.subtract(const Duration(hours: 3)), endAt: now.subtract(const Duration(hours: 2)))],
        records: [panelRecord('t1', {1}), panelRecord('t3', {1})],
      );
      await _pump(tester, service);
      expect(find.text('Susulan sesi 1'), findsOneWidget, reason: 'only Gita missed it');
      await _tapLast(tester, 'Susulan sesi 1');
      expect(find.text('Buka susulan sesi 1 untuk Gita (R-12)?'), findsOneWidget);
      await tester.tap(find.textContaining('di bawah pengawasan saya'));
      await tester.pumpAndSettle();
      await _tapLast(tester, 'Buka susulan');
      expect(service.calls, ['treat:B1:1:makeup:t2:60']);
      expect(find.text('Susulan dipakai: sesi 1'), findsOneWidget);
      expect(find.text('Susulan sesi 1'), findsNothing, reason: 'one make-up per student');
      // The first session may still be re-opened today for latecomers.
      expect(find.text('Buka ulang sesi 1'), findsNothing, reason: 'every candidate has done or is doing session 1');
    });

    testWidgets('without a seeded plan the section explains the tooling step', (tester) async {
      final service = FakeResearchPanelService(study: activeStudy(treatmentPlanVersion: null), participants: [panelParticipant('t1')]);
      await _pump(tester, service);
      expect(find.textContaining('Rencana treatment belum disiapkan'), findsWidgets);
      expect(find.text('Buka sesi 1'), findsNothing);
    });
  });
}
