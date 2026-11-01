import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/widgets/app_nav_shell.dart';

void main() {
  final destinations = [
    AppNavDestination(
      label: 'One',
      icon: Icons.home,
      body: const Text('Body One'),
    ),
    AppNavDestination(
      label: 'Two',
      icon: Icons.settings,
      body: const Text('Body Two'),
    ),
  ];

  void setSurfaceSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('narrow width renders the custom top navigation, not a rail', (
    tester,
  ) async {
    setSurfaceSize(tester, const Size(390, 800));

    await tester.pumpWidget(
      MaterialApp(home: AppNavShell(destinations: destinations)),
    );

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Body One'), findsOneWidget);
  });

  testWidgets(
    'wide width renders NavigationRail, not the custom top navigation',
    (tester) async {
      setSurfaceSize(tester, const Size(1000, 800));

      await tester.pumpWidget(
        MaterialApp(home: AppNavShell(destinations: destinations)),
      );

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Body One'), findsOneWidget);
    },
  );

  testWidgets(
    'narrow width: tapping the second nav item switches the visible body',
    (tester) async {
      setSurfaceSize(tester, const Size(390, 800));

      await tester.pumpWidget(
        MaterialApp(home: AppNavShell(destinations: destinations)),
      );

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Body One'), findsOneWidget);
      expect(find.text('Body Two'), findsNothing);

      await tester.tap(find.text('Two').first);
      await tester.pumpAndSettle();

      expect(find.text('Body One'), findsNothing);
      expect(find.text('Body Two'), findsOneWidget);
    },
  );

  testWidgets('selecting another destination changes the visible body', (
    tester,
  ) async {
    setSurfaceSize(tester, const Size(1000, 800));

    await tester.pumpWidget(
      MaterialApp(home: AppNavShell(destinations: destinations)),
    );

    expect(find.text('Body One'), findsOneWidget);
    expect(find.text('Body Two'), findsNothing);

    await tester.tap(find.text('Two').first);
    await tester.pumpAndSettle();

    expect(find.text('Body One'), findsNothing);
    expect(find.text('Body Two'), findsOneWidget);
  });

  group('onLogout action', () {
    testWidgets(
      'renders logout icon button and calls onLogout on tap (narrow width)',
      (tester) async {
        setSurfaceSize(tester, const Size(390, 800));
        var logoutCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: AppNavShell(
              destinations: destinations,
              onLogout: () => logoutCalled = true,
            ),
          ),
        );

        final logoutButton = find.byTooltip('Keluar');
        expect(logoutButton, findsOneWidget);
        expect(find.byIcon(Icons.logout), findsOneWidget);

        await tester.tap(logoutButton);
        await tester.pump();

        expect(logoutCalled, isTrue);
      },
    );

    testWidgets(
      'renders logout icon button and calls onLogout on tap (wide width)',
      (tester) async {
        setSurfaceSize(tester, const Size(1000, 800));
        var logoutCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: AppNavShell(
              destinations: destinations,
              onLogout: () => logoutCalled = true,
            ),
          ),
        );

        final logoutButton = find.byTooltip('Keluar');
        expect(logoutButton, findsOneWidget);
        expect(find.byIcon(Icons.logout), findsOneWidget);

        await tester.tap(logoutButton);
        await tester.pump();

        expect(logoutCalled, isTrue);
      },
    );

    testWidgets('does not render logout icon button when onLogout is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppNavShell(destinations: destinations, onLogout: null),
        ),
      );

      expect(find.byTooltip('Keluar'), findsNothing);
      expect(find.byIcon(Icons.logout), findsNothing);
    });
  });

  testWidgets('tablet widths use the compact rail, large windows extend it', (
    tester,
  ) async {
    setSurfaceSize(tester, const Size(1000, 800));
    await tester.pumpWidget(
      MaterialApp(home: AppNavShell(destinations: destinations)),
    );
    expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).extended, isFalse);

    setSurfaceSize(tester, const Size(1280, 800));
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).extended, isTrue);
  });

  testWidgets('the wide layout keeps logout reachable without an app bar', (
    tester,
  ) async {
    setSurfaceSize(tester, const Size(1000, 600));
    await tester.pumpWidget(
      MaterialApp(
        home: AppNavShell(destinations: destinations, onLogout: () {}),
      ),
    );
    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('Keluar').hitTestable(), findsOneWidget);
  });

  testWidgets('crossing the breakpoint keeps the state of the open destination', (
    tester,
  ) async {
    setSurfaceSize(tester, const Size(390, 800));
    await tester.pumpWidget(
      MaterialApp(
        home: AppNavShell(
          destinations: const [
            AppNavDestination(
              label: 'One',
              icon: Icons.home,
              body: Material(child: TextField()),
            ),
            AppNavDestination(
              label: 'Two',
              icon: Icons.settings,
              body: Text('Body Two'),
            ),
          ],
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'setengah terisi');

    // A tablet rotating, or a window being resized.
    setSurfaceSize(tester, const Size(1000, 800));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('setengah terisi'), findsOneWidget);

    setSurfaceSize(tester, const Size(390, 800));
    await tester.pumpAndSettle();
    expect(find.text('setengah terisi'), findsOneWidget);
  });
}
