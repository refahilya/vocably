import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:firebase_core_web/firebase_core_web.dart'
    show supportedFirebaseJsSdkVersion;

/// The window globals FlutterFire's interop reads (`@JS('firebase_core')`,
/// `@JS('firebase_auth')`, `@JS('firebase_firestore')`), mapped to the SDK
/// bundles `firebase_core_web` would otherwise inject. Firestore uses the
/// pipelines bundle, as FlutterFire does.
///
/// **Every FlutterFire web plugin the app depends on must be listed here.**
/// Once `firebase_core` is set FlutterFire injects nothing, so a plugin
/// missing from this map would find its global undefined.
const _serviceBundles = {
  'firebase_auth': 'firebase-auth.js',
  'firebase_firestore': 'firebase-firestore-pipelines.js',
};

/// Imports the Firebase JS SDK (same version FlutterFire expects, so an
/// upgrade of `firebase_core_web` moves this along) and publishes it on the
/// window globals. The dynamic `import()` runs from `main.dart.js`, which the
/// CSP allows as `'self'`; the bundles come from `https://www.gstatic.com`,
/// also allowed by `script-src`.
Future<void> preloadFirebaseWebSdk() async {
  if (globalContext.has('firebase_core')) return;

  const base = 'https://www.gstatic.com/firebasejs/$supportedFirebaseJsSdkVersion';
  // firebase-app.js first, then the services in parallel — FlutterFire does
  // the same to avoid a WebKit module-evaluation race on the shared
  // firebase-app.js import (flutterfire#18436).
  final core = await importModule('$base/firebase-app.js'.toJS).toDart;
  final services = await Future.wait(
    _serviceBundles.values.map(
      (bundle) => importModule('$base/$bundle'.toJS).toDart,
    ),
  );
  for (final (index, global) in _serviceBundles.keys.indexed) {
    globalContext[global] = services[index];
  }
  // Set last: FlutterFire treats a present `firebase_core` as "all loaded".
  globalContext['firebase_core'] = core;
}
