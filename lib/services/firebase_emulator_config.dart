import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Opt-in local testing against the Firebase Emulators (Firestore + Auth),
/// for manual end-to-end checks of the research assessment with dummy
/// accounts (`tools/research/README.md`, "Running the app against the
/// emulators").
///
/// Enabled only by `--dart-define=USE_FIREBASE_EMULATORS=true` in a debug
/// or profile run. A **release** build with that define refuses to start,
/// and without it the emulator branch is compile-time dead code — so a
/// production build can never talk to an emulator, and a normal run can
/// never talk to one by accident.
const bool kUseFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
);

/// The offline-only demo project the emulators run under
/// (`tools/research/lib/emulatorEnv.js`).
const String kEmulatorProjectId = 'demo-vocably-test';
const String kEmulatorHost = '127.0.0.1';
const int kFirestoreEmulatorPort = 8080;
const int kAuthEmulatorPort = 9099;

enum FirebaseTarget { production, emulators }

/// Decides the target; throws [StateError] for a release build that asks
/// for the emulators.
FirebaseTarget resolveFirebaseTarget({
  required bool useEmulators,
  required bool isRelease,
}) {
  if (!useEmulators) return FirebaseTarget.production;
  if (isRelease) {
    throw StateError(
      'USE_FIREBASE_EMULATORS is not allowed in a release build.',
    );
  }
  return FirebaseTarget.emulators;
}

/// The app's options re-pointed at the demo project, so data seeded into
/// the emulators by the research tooling is the data the app sees.
FirebaseOptions emulatorFirebaseOptions(FirebaseOptions base) =>
    base.copyWith(projectId: kEmulatorProjectId);

/// Connects Firestore and Auth to the local emulators. Must run right after
/// `Firebase.initializeApp`, before any other Firebase call.
Future<void> connectToFirebaseEmulators() async {
  FirebaseFirestore.instance.useFirestoreEmulator(
    kEmulatorHost,
    kFirestoreEmulatorPort,
  );
  await FirebaseAuth.instance.useAuthEmulator(kEmulatorHost, kAuthEmulatorPort);
}
