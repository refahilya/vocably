import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/firebase_service.dart';

part 'firebase_status_provider.g.dart';

/// Outcome of the Milestone 1 Firebase initialization check.
///
/// This represents *application/SDK initialization status* only — not a
/// Firestore connectivity or permission check. No application schema
/// exists yet (see DATA_MODEL.md), so no Firestore read/write is performed
/// here; a permission-denied error from the deny-all baseline rules must
/// never be interpreted as [failed].
enum FirebaseStatus { ready, failed }

/// Reports whether Firebase (`firebase_core`, with `firebase_auth` and
/// `cloud_firestore` confirmed configured) initialized successfully.
///
/// This is also the Milestone 1 proof that the Riverpod code-generation
/// pipeline (build_runner + riverpod_generator) works end-to-end.
@riverpod
class FirebaseStatusNotifier extends _$FirebaseStatusNotifier {
  @override
  Future<FirebaseStatus> build() async {
    const service = FirebaseService();
    await service.initialize();

    // Accessing these confirms the Auth/Firestore SDKs are configured for
    // this app without performing any network read/write.
    service.auth;
    service.firestore;

    return service.isInitialized ? FirebaseStatus.ready : FirebaseStatus.failed;
  }
}
