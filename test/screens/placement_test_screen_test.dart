import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/placement_attempt.dart';
import 'package:vocably/models/placement_instrument.dart';
import 'package:vocably/providers/placement_test_providers.dart';
import 'package:vocably/providers/research_assessment_providers.dart';
import 'package:vocably/screens/student/placement_test/placement_test_screen.dart';
import 'package:vocably/theme/theme.dart';
import 'package:vocably/utils/story_markers.dart';

import '../support/fake_placement_service.dart';
import '../support/fake_research_assessment_service.dart' show openStudy;

void main() {
  late FakePlacementService service;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placementServiceProvider.overrideWithValue(service),
          researchAssessmentRandomProvider.overrideWithValue(Random(3)),
        ],
        child: const MaterialApp(home: PlacementTestScreen(uid: 'student-1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls [finder] into view first (the instructions are taller than a phone).
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Every leaf text span under [span] with its inherited style applied.
  List<({String text, TextStyle style})> leaves(InlineSpan span, [TextStyle inherited = const TextStyle()]) {
    final result = <({String text, TextStyle style})>[];
    if (span is! TextSpan) return result;
    final style = inherited.merge(span.style);
    if (span.text != null) result.add((text: span.text!, style: style));
    for (final child in span.children ?? const <InlineSpan>[]) {
      result.addAll(leaves(child, style));
    }
    return result;
  }

  /// The rendered sentence of the item currently on screen.
  List<({String text, TextStyle style})> sentenceSpans(WidgetTester tester, PlacementItem item) {
    final plain = stripStoryMarkers(item.sentenceMarkup);
    final rich = tester.widgetList<RichText>(find.byType(RichText)).where((r) => r.text.toPlainText() == plain);
    expect(rich, hasLength(1), reason: item.id);
    return leaves(rich.single.text);
  }

  setUp(() => service = FakePlacementService());

  testWidgets('shows the verbatim instructions, then one item per screen with options A–E', (tester) async {
    await pump(tester);
    expect(find.text('Tes Penempatan Kosakata'), findsOneWidget);
    expect(find.textContaining('Tes ini terdiri atas 50 soal pilihan ganda'), findsOneWidget);
    await tap(tester, find.text('Mulai'));
    expect(find.text('Soal 1 dari 50'), findsOneWidget);
    expect(find.textContaining('E. Saya tidak tahu'), findsOneWidget);
    expect(find.textContaining('A1'), findsNothing, reason: 'band labels are never shown');
    await tap(tester, find.byKey(const ValueKey('placement-option-E')));
    expect(find.text('Tersimpan'), findsOneWidget);
    expect(service.attempts.values.single.answers.values.single, 'E');
  });

  testWidgets('on every item only the marked word is bold and underlined; the rest of the sentence is regular', (tester) async {
    await pump(tester);
    await tap(tester, find.text('Mulai'));
    final container = ProviderScope.containerOf(tester.element(find.byType(PlacementTestScreen)));
    final controller = container.read(placementTestControllerProvider('student-1').notifier);
    final items = (container.read(placementTestControllerProvider('student-1')) as PlacementTestAnswering).items;
    expect(items, hasLength(50));

    final highlighted = <String>{};
    for (var i = 0; i < items.length; i++) {
      controller.goTo(i);
      await tester.pumpAndSettle();
      final surfaceForm = items[i].segments.whereType<MarkedStorySegment>().single.surfaceForm;
      final spans = sentenceSpans(tester, items[i]);
      final target = spans.where((s) => s.style.decoration == TextDecoration.underline).toList();
      expect(target.map((s) => s.text), [surfaceForm], reason: items[i].id);
      expect(target.single.style.fontWeight, FontWeight.bold, reason: items[i].id);
      for (final span in spans.where((s) => s.text != surfaceForm)) {
        expect(span.style.fontWeight, isNot(FontWeight.bold), reason: '${items[i].id}: "${span.text}"');
        expect(span.style.decoration, isNot(TextDecoration.underline), reason: '${items[i].id}: "${span.text}"');
      }
      highlighted.add(target.single.text);
    }
    expect(highlighted, hasLength(50));
    // Inflected forms prove the highlight comes from the marker, not the base word.
    expect(highlighted, containsAll(['encourages', 'delayed', 'persisted']));
  });

  testWidgets('the assessment text styles differ only where the highlight needs them to', (tester) async {
    expect(AppTextStyles.assessmentSentence.fontWeight, FontWeight.normal);
    expect(AppTextStyles.assessmentSentence.decoration, isNull);
    expect(AppTextStyles.assessmentTarget.fontWeight, FontWeight.bold);
    expect(AppTextStyles.assessmentTarget.decoration, TextDecoration.underline);
    expect(AppTextStyles.assessmentSentence.fontSize, AppTextStyles.wordTitle.fontSize);
    expect(AppTextStyles.assessmentSentence.color, AppTextStyles.wordTitle.color);
    expect(AppTextStyles.wordTitle.fontWeight, FontWeight.bold, reason: 'other screens keep the bold title');
  });

  testWidgets('the window closing after the instructions loaded shows "Tes belum dibuka", not a connection error', (tester) async {
    service.participant = pendingParticipant();
    await pump(tester);
    expect(find.text('Mulai'), findsOneWidget);
    service.study = openStudy(open: const {});
    await tap(tester, find.text('Mulai'));
    expect(find.text('Tes belum dibuka. Tunggu arahan pengawas.'), findsOneWidget);
    expect(find.textContaining('Periksa koneksi internet'), findsNothing);
    expect(find.text('Mulai'), findsNothing);
  });

  testWidgets('the summary lists unanswered items and keeps "Kirim jawaban" disabled until all 50 are answered', (tester) async {
    await pump(tester);
    await tap(tester, find.text('Mulai'));
    await tap(tester, find.byKey(const ValueKey('placement-option-B')));
    final container = ProviderScope.containerOf(tester.element(find.byType(PlacementTestScreen)));
    container.read(placementTestControllerProvider('student-1').notifier).openSummary();
    await tester.pumpAndSettle();
    expect(find.textContaining('Masih ada soal yang belum dijawab: nomor 2, 3'), findsOneWidget);
    final submit = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Kirim jawaban'));
    expect(submit.onPressed, isNull);
  });

  testWidgets('submission asks for confirmation; the result shows only the level', (tester) async {
    await pump(tester);
    await tap(tester, find.text('Mulai'));
    final container = ProviderScope.containerOf(tester.element(find.byType(PlacementTestScreen)));
    final controller = container.read(placementTestControllerProvider('student-1').notifier);
    final answers = service.answersFor([10, 10, 7, 2, 0]);
    final s = container.read(placementTestControllerProvider('student-1')) as PlacementTestAnswering;
    for (var i = 0; i < s.items.length; i++) {
      controller.goTo(i);
      await controller.select(answers[s.items[i].id]!);
    }
    controller.openSummary();
    await tester.pumpAndSettle();
    await tap(tester, find.widgetWithText(FilledButton, 'Kirim jawaban'));
    expect(find.text('Setelah dikirim, jawaban tidak dapat diubah. Kirim sekarang?'), findsOneWidget);
    await tap(tester, find.text('Periksa lagi'));
    expect(service.submitCalls, 0);
    await tap(tester, find.widgetWithText(FilledButton, 'Kirim jawaban'));
    await tap(tester, find.widgetWithText(FilledButton, 'Kirim'));
    expect(find.text('Terima kasih. Jawabanmu sudah tersimpan.'), findsOneWidget);
    expect(find.text('Level kamu: B1', findRichText: true), findsOneWidget);
    expect(find.textContaining('/10'), findsNothing);
    expect(find.textContaining('skor'), findsNothing);
    expect(service.attempts.values.single.status, PlacementAttemptStatus.scored);
  });

  testWidgets('a closed research window shows the supervisor message', (tester) async {
    service.participant = pendingParticipant();
    service.study = openStudy(open: const {});
    await pump(tester);
    expect(find.text('Tes belum dibuka. Tunggu arahan pengawas.'), findsOneWidget);
  });

  testWidgets('hiding the app is recorded through AppLifecycleListener and changes nothing on screen', (tester) async {
    await pump(tester);
    await tap(tester, find.text('Mulai'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(service.hiddenCalls, 1);
    expect(service.attempts.values.single.tabSwitchCount, 1);
    expect(find.text('Soal 1 dari 50'), findsOneWidget);
    // Blur alone (inactive without hidden) is not counted.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(service.hiddenCalls, 1);
  });
}
