import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/firebase_options.dart';
import 'package:vocably/services/firebase_emulator_config.dart';

void main() {
  test('production unless the emulators are explicitly requested', () {
    expect(
      resolveFirebaseTarget(useEmulators: false, isRelease: false),
      FirebaseTarget.production,
    );
    expect(
      resolveFirebaseTarget(useEmulators: false, isRelease: true),
      FirebaseTarget.production,
    );
    expect(
      resolveFirebaseTarget(useEmulators: true, isRelease: false),
      FirebaseTarget.emulators,
    );
  });

  test('a release build refuses the emulators', () {
    expect(
      () => resolveFirebaseTarget(useEmulators: true, isRelease: true),
      throwsStateError,
    );
  });

  test('the define is off by default (tests and normal builds)', () {
    expect(kUseFirebaseEmulators, isFalse);
  });

  test('emulator options keep the app config but use the demo project', () {
    const base = FirebaseOptions(
      apiKey: 'key',
      appId: 'app',
      messagingSenderId: 'sender',
      projectId: 'vocably-idn-en',
    );
    final options = emulatorFirebaseOptions(base);
    expect(options.projectId, 'demo-vocably-test');
    expect(options.appId, 'app');
    expect(DefaultFirebaseOptions.web.projectId, 'vocably-idn-en');
  });
}
