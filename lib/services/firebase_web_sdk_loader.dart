/// Loads the Firebase JS SDK on web before `Firebase.initializeApp`, so the
/// Content-Security-Policy in `firebase.json` can forbid inline scripts.
///
/// Left alone, FlutterFire (`firebase_core_web`) loads the SDK by injecting
/// one **inline** `<script>` per service, which a CSP without
/// `'unsafe-inline'` blocks — Firebase then never starts. FlutterFire skips
/// that injection entirely when `window.firebase_core` already exists ("the
/// user has added the scripts"), so the web implementation imports the same
/// modules from `main.dart.js` itself. No-op on other platforms.
library;

export 'firebase_web_sdk_loader_stub.dart'
    if (dart.library.js_interop) 'firebase_web_sdk_loader_web.dart';
