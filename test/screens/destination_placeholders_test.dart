import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/models/app_user.dart';
import 'package:vocably/providers/auth_providers.dart';
import 'package:vocably/screens/student/dashboard/dashboard_placeholder.dart';
import 'package:vocably/screens/student/history/history_placeholder.dart';
import 'package:vocably/screens/teacher/target_words/target_words_placeholder.dart';
import 'package:vocably/services/auth_service.dart';
import 'package:vocably/utils/role.dart';

/// Records whether `signOut()` was called, without ever touching Firebase
/// — the other `AuthService` methods are never invoked by these widgets,
/// so this only needs to override the one method they call.
class _FakeAuthService extends AuthService {
  bool signOutCalled = false;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

final _studentProfile = AppUser(
  uid: 'student-1',
  email: 'siswa@example.com',
  name: 'Siswa Uji',
  role: Role.siswa,
  createdAt: DateTime(2026, 1, 1),
);

final _teacherProfile = AppUser(
  uid: 'teacher-1',
  email: 'guru@example.com',
  name: 'Guru Uji',
  role: Role.guru,
  createdAt: DateTime(2026, 1, 1),
);

/// Wraps [destination] the way a real `AppNavDestination.body` would be
/// hosted — inside a single app-level `Scaffold`/`AppBar` supplied by the
/// harness (standing in for `AppNavShell`), never by the destination
/// itself. Asserting `findsOneWidget` (not `findsNothing`) for both below
/// is what proves the destination didn't add a second one of its own.
Future<void> _pumpDestination(
  WidgetTester tester,
  Widget destination, {
  AuthService? authService,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (authService != null)
          authServiceProvider.overrideWithValue(authService),
      ],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Harness')),
          body: destination,
        ),
      ),
    ),
  );
}

void main() {
  group('DashboardPlaceholder (Belajar)', () {
    testWidgets('shows destination name, profile name, and no nested Scaffold/AppBar', (
      tester,
    ) async {
      await _pumpDestination(
        tester,
        DashboardPlaceholder(profile: _studentProfile),
      );

      expect(find.text('Belajar'), findsOneWidget);
      expect(find.text('Selamat datang, Siswa Uji'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('Keluar button calls the existing authServiceProvider.signOut()', (
      tester,
    ) async {
      final fakeAuth = _FakeAuthService();
      await _pumpDestination(
        tester,
        DashboardPlaceholder(profile: _studentProfile),
        authService: fakeAuth,
      );

      await tester.tap(find.text('Keluar'));
      await tester.pump();

      expect(fakeAuth.signOutCalled, isTrue);
    });
  });

  group('HistoryPlaceholder (Riwayat)', () {
    testWidgets('shows destination name, no logout button, no nested Scaffold/AppBar', (
      tester,
    ) async {
      await _pumpDestination(tester, const HistoryPlaceholder());

      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.text('Keluar'), findsNothing);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });
  });

  group('TargetWordsPlaceholder (Target Kata)', () {
    testWidgets('shows destination name, profile name, and no nested Scaffold/AppBar', (
      tester,
    ) async {
      await _pumpDestination(
        tester,
        TargetWordsPlaceholder(profile: _teacherProfile),
      );

      expect(find.text('Target Kata'), findsOneWidget);
      expect(find.text('Selamat datang, Guru Uji'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('Keluar button calls the existing authServiceProvider.signOut()', (
      tester,
    ) async {
      final fakeAuth = _FakeAuthService();
      await _pumpDestination(
        tester,
        TargetWordsPlaceholder(profile: _teacherProfile),
        authService: fakeAuth,
      );

      await tester.tap(find.text('Keluar'));
      await tester.pump();

      expect(fakeAuth.signOutCalled, isTrue);
    });
  });
}
