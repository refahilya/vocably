import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/models/app_user.dart';
import 'package:vocably/models/vocab_bundle_entry.dart';
import 'package:vocably/providers/vocab_bundle_providers.dart';
import 'package:vocably/providers/vocab_management_providers.dart';
import 'package:vocably/screens/teacher/vocab_management/edit_kata_screen.dart';
import 'package:vocably/screens/teacher/vocab_management/tambah_kosakata_screen.dart';
import 'package:vocably/screens/teacher/vocab_management/vocab_management_screen.dart';
import 'package:vocably/services/topics_service.dart';
import 'package:vocably/services/vocab_bundle_service.dart';
import 'package:vocably/services/vocab_word_service.dart';
import 'package:vocably/utils/role.dart';

class _FakeVocabBundleService extends VocabBundleService {
  @override
  Future<List<VocabBundleEntry>> loadLevelWithDelta({
    required String cefrLevel,
    required DateTime bundleGeneratedAt,
  }) async => [];
}

class _FakeVocabWordService extends VocabWordService {}
class _FakeTopicsService extends TopicsService {}

final _teacherProfile = AppUser(
  uid: 'teacher-1',
  email: 'guru@example.com',
  name: 'Guru Uji',
  role: Role.guru,
  createdAt: DateTime(2026, 1, 1),
);

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vocabBundleServiceProvider.overrideWithValue(_FakeVocabBundleService()),
        vocabWordServiceProvider.overrideWithValue(_FakeVocabWordService()),
        topicsServiceProvider.overrideWithValue(_FakeTopicsService()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: VocabManagementScreen(profile: _teacherProfile),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('VocabManagementScreen', () {
    testWidgets('renders segmented control and switches between Tambah and Edit screens', (
      tester,
    ) async {
      await _pumpScreen(tester);

      expect(find.byType(SegmentedButton<VocabManagementTab>), findsOneWidget);
      expect(find.text('Tambah Kosakata'), findsWidgets);
      expect(find.text('Edit Kata'), findsOneWidget);

      // Default is TambahKosakataScreen
      expect(find.byType(TambahKosakataScreen), findsOneWidget);
      expect(find.byType(EditKataScreen), findsNothing);

      // Tap Edit Kata segment
      await tester.tap(find.text('Edit Kata'));
      await tester.pumpAndSettle();

      expect(find.byType(EditKataScreen), findsOneWidget);
      expect(find.byType(TambahKosakataScreen), findsNothing);
    });
  });
}
