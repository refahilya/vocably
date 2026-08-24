import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/widgets/app_nav_shell.dart';

void main() {
  final destinations = [
    AppNavDestination(label: 'One', icon: Icons.home, body: const Text('Body One')),
    AppNavDestination(label: 'Two', icon: Icons.settings, body: const Text('Body Two')),
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

    await tester.pumpWidget(MaterialApp(home: AppNavShell(destinations: destinations)));

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Body One'), findsOneWidget);
  });

  testWidgets('wide width renders NavigationRail, not the custom top navigation', (
    tester,
  ) async {
    setSurfaceSize(tester, const Size(1000, 800));

    await tester.pumpWidget(MaterialApp(home: AppNavShell(destinations: destinations)));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Body One'), findsOneWidget);
  });

  testWidgets(
    'narrow width: tapping the second nav item switches the visible body',
    (tester) async {
      setSurfaceSize(tester, const Size(390, 800));

      await tester.pumpWidget(MaterialApp(home: AppNavShell(destinations: destinations)));

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Body One'), findsOneWidget);
      expect(find.text('Body Two'), findsNothing);

      await tester.tap(find.text('Two').first);
      await tester.pumpAndSettle();

      expect(find.text('Body One'), findsNothing);
      expect(find.text('Body Two'), findsOneWidget);
    },
  );

  testWidgets('selecting another destination changes the visible body', (tester) async {
    setSurfaceSize(tester, const Size(1000, 800));

    await tester.pumpWidget(MaterialApp(home: AppNavShell(destinations: destinations)));

    expect(find.text('Body One'), findsOneWidget);
    expect(find.text('Body Two'), findsNothing);

    await tester.tap(find.text('Two').first);
    await tester.pumpAndSettle();

    expect(find.text('Body One'), findsNothing);
    expect(find.text('Body Two'), findsOneWidget);
  });
}
