import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/theme/theme.dart';
import 'package:vocably/widgets/app_feedback.dart';
import 'package:vocably/widgets/app_layout.dart';

void main() {
  void sized(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget child) => MaterialApp(
    theme: AppTheme.themeData,
    home: Scaffold(body: child),
  );

  group('AppContent', () {
    testWidgets('caps the width and centers on wide windows', (tester) async {
      sized(tester, const Size(1920, 1080));
      const key = ValueKey('content');
      await tester.pumpWidget(
        app(const AppContent(maxWidth: 680, child: SizedBox(key: key, height: 10))),
      );
      final rect = tester.getRect(find.byKey(key));
      expect(rect.width, 680 - 2 * AppSpacing.xl);
      expect(rect.center.dx, 960);
    });

    testWidgets('gives children the full width on phones, minus the gutter', (tester) async {
      sized(tester, const Size(320, 640));
      const key = ValueKey('content');
      await tester.pumpWidget(
        app(const AppContent(child: SizedBox(key: key, height: 10))),
      );
      expect(tester.getSize(find.byKey(key)).width, 320 - 2 * AppSpacing.md);
    });

    testWidgets('a button inside the bottom bar spans the bar', (tester) async {
      sized(tester, const Size(390, 844));
      await tester.pumpWidget(
        app(
          AppBottomBar(
            child: FilledButton(onPressed: () {}, child: const Text('Submit')),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(FilledButton)).width,
        390 - 2 * AppSpacing.md,
      );
    });
  });

  group('AppScrollPage', () {
    testWidgets('the wheel scrolls over the margins beside the content', (tester) async {
      sized(tester, const Size(1920, 600));
      await tester.pumpWidget(
        app(
          const AppScrollPage(
            maxWidth: 400,
            child: SizedBox(height: 3000, child: Placeholder()),
          ),
        ),
      );
      expect(tester.getSize(find.byType(SingleChildScrollView)).width, 1920);
    });
  });

  group('AppTwoPane', () {
    const primary = Text('primary');
    const side = Text('side');

    testWidgets('stacks on narrow windows, side first when asked', (tester) async {
      sized(tester, const Size(390, 844));
      await tester.pumpWidget(
        app(const AppTwoPane(primary: primary, side: side, sideFirst: true)),
      );
      expect(
        tester.getTopLeft(find.text('side')).dy,
        lessThan(tester.getTopLeft(find.text('primary')).dy),
      );
    });

    testWidgets('sits side by side at the breakpoint', (tester) async {
      sized(tester, const Size(1280, 800));
      await tester.pumpWidget(app(const AppTwoPane(primary: primary, side: side)));
      expect(
        tester.getTopLeft(find.text('side')).dx,
        greaterThan(tester.getTopLeft(find.text('primary')).dx),
      );
    });
  });

  group('AppResponsiveList', () {
    Future<void> pumpList(WidgetTester tester, double width) async {
      sized(tester, Size(width, 800));
      await tester.pumpWidget(
        app(
          AppResponsiveList(
            itemCount: 7,
            minItemWidth: 300,
            itemBuilder: (context, i) => Text('item $i'),
          ),
        ),
      );
    }

    int rowOf(WidgetTester tester, int i) =>
        tester.getTopLeft(find.text('item $i')).dy.round();

    testWidgets('is a single column on phones', (tester) async {
      await pumpList(tester, 390);
      expect(rowOf(tester, 1), greaterThan(rowOf(tester, 0)));
    });

    testWidgets('gains columns as the window grows, keeping item order', (tester) async {
      await pumpList(tester, 1000);
      expect(rowOf(tester, 2), rowOf(tester, 0));
      expect(rowOf(tester, 3), greaterThan(rowOf(tester, 2)));
      expect(find.text('item 6'), findsOneWidget);
    });

    testWidgets('never exceeds maxColumns', (tester) async {
      await pumpList(tester, 3000);
      expect(rowOf(tester, 3), greaterThan(rowOf(tester, 2)));
    });
  });

  group('feedback widgets', () {
    testWidgets('a notice with an action never overflows a 320px phone', (tester) async {
      sized(tester, const Size(320, 640));
      await tester.pumpWidget(
        app(
          AppContent(
            child: AppNotice(
              text: 'Gagal membuat cerita. Periksa koneksi internet, lalu coba lagi nanti.',
              tone: AppTone.error,
              action: TextButton(onPressed: () {}, child: const Text('Coba lagi')),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a status message scrolls instead of clipping on a short window', (tester) async {
      sized(tester, const Size(320, 220));
      await tester.pumpWidget(
        app(
          AppStateMessage(
            icon: Icons.lock_outline,
            title: 'Tes belum dibuka',
            body: 'Tes belum dibuka. Tunggu arahan pengawas. ' * 4,
            action: FilledButton(onPressed: () {}, child: const Text('Muat ulang')),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Muat ulang'));
      await tester.pumpAndSettle();
      expect(find.text('Muat ulang').hitTestable(), findsOneWidget);
    });

    testWidgets('a status message works inside a scrolling page too', (tester) async {
      sized(tester, const Size(390, 844));
      await tester.pumpWidget(
        app(
          const AppScrollPage(
            child: AppStateMessage(icon: Icons.book, title: 'Cerita akan muncul di sini'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Cerita akan muncul di sini'), findsOneWidget);
    });
  });
}
