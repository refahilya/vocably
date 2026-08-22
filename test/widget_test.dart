import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/app.dart';

void main() {
  testWidgets('VocablyApp builds without throwing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: VocablyApp()),
    );

    // Milestone 1 only needs to prove the app widget tree builds; the
    // connection-check screen's Firebase call resolves asynchronously and
    // isn't awaited here (no Firebase test setup exists yet for `flutter
    // test`, which runs outside a browser/device).
    await tester.pump();

    expect(find.text('Vocably'), findsOneWidget);
  });
}
