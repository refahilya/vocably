import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/app_user.dart';
import 'package:vocably/providers/auth_providers.dart';
import 'package:vocably/screens/student/placement_test/placement_test_offer_screen.dart';
import 'package:vocably/screens/student/placement_test/placement_test_placeholder_screen.dart';
import 'package:vocably/services/user_service.dart';
import 'package:vocably/utils/role.dart';

class _FakeUserService extends UserService {
  final List<String> promptedUids = [];

  @override
  Future<void> markPlacementTestPrompted(String uid) async {
    promptedUids.add(uid);
  }
}

final _studentProfile = AppUser(
  uid: 'student-1',
  email: 'siswa@example.com',
  name: 'Siswa Uji',
  role: Role.siswa,
  createdAt: DateTime(2026, 1, 1),
);

Future<void> _pumpOfferScreen(WidgetTester tester, _FakeUserService userService) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [userServiceProvider.overrideWithValue(userService)],
      child: MaterialApp(home: PlacementTestOfferScreen(profile: _studentProfile)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows both choices, opt-out wording is not discouraging', (tester) async {
    await _pumpOfferScreen(tester, _FakeUserService());

    expect(find.text('Mulai Tes'), findsOneWidget);
    expect(find.text('Nanti Saja'), findsOneWidget);
  });

  testWidgets('"Nanti Saja" marks the student as prompted and does not navigate anywhere', (
    tester,
  ) async {
    final userService = _FakeUserService();
    await _pumpOfferScreen(tester, userService);

    await tester.tap(find.text('Nanti Saja'));
    await tester.pumpAndSettle();

    expect(userService.promptedUids, ['student-1']);
    expect(find.byType(PlacementTestPlaceholderScreen), findsNothing);
  });

  testWidgets('"Mulai Tes" marks the student as prompted and opens the placeholder test screen', (
    tester,
  ) async {
    final userService = _FakeUserService();
    await _pumpOfferScreen(tester, userService);

    await tester.tap(find.text('Mulai Tes'));
    await tester.pumpAndSettle();

    expect(userService.promptedUids, ['student-1']);
    expect(find.byType(PlacementTestPlaceholderScreen), findsOneWidget);
  });
}
