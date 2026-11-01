import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/screens/auth/login_screen.dart';
import 'package:vocably/screens/auth/sign_up_screen.dart';
import 'package:vocably/theme/theme.dart';

/// Presentation-level guarantees of the sign-in screens. Sign-in itself goes
/// through Firebase and is covered in `test/app_routing_test.dart` and by the
/// provider tests.
void main() {
  Future<void> pumpLogin(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.themeData, home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    final label = '${size.width.toInt()}px';

    testWidgets('empty fields show the validation message @ $label', (tester) async {
      await pumpLogin(tester, size);
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pump();
      expect(find.text('Wajib diisi'), findsNWidgets(2));
    });

    testWidgets('the root sign-in screen has no back button @ $label', (tester) async {
      await pumpLogin(tester, size);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('every pushed auth screen can go back @ $label', (tester) async {
      await pumpLogin(tester, size);

      await tester.tap(find.text('Belum punya akun? Daftar'));
      await tester.pumpAndSettle();
      expect(find.byType(SignUpScreen), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      final toLogin = find.text('Sudah punya akun? Masuk');
      await tester.ensureVisible(toLogin);
      await tester.pumpAndSettle();
      await tester.tap(toLogin);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget, reason: 'a Login pushed from Daftar');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(SignUpScreen), findsOneWidget);
    });
  }

  testWidgets('the teacher access code field still appears on request', (tester) async {
    await pumpLogin(tester, const Size(390, 844));
    await tester.tap(find.text('Belum punya akun? Daftar'));
    await tester.pumpAndSettle();

    expect(find.text('Kode Akses Guru'), findsNothing);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('Kode Akses Guru'), findsOneWidget);

    final submit = find.widgetWithText(FilledButton, 'Daftar');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Wajib diisi'), findsNWidgets(4));
  });
}
