import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

/// Thin wrapper around Firebase SDK initialization and access.
///
/// Per CLAUDE.md §4, every call to Firebase must go through a `services/`
/// layer rather than being made directly from widgets/providers.
///
/// Milestone 1 scope: prove that `firebase_core`, `firebase_auth`, and
/// `cloud_firestore` are wired and initialize successfully against the real
/// Firebase project (`vocably-idn-en`). This class intentionally performs
/// no Firestore reads or writes — there is no application schema yet (see
/// DATA_MODEL.md), and a Firestore permission error (e.g. from the
/// Milestone 1 deny-all baseline rules) must never be mistaken for a
/// Firebase initialization failure.
class FirebaseService {
  const FirebaseService();

  /// Initializes the Firebase app for the current platform. Safe to call
  /// more than once — a second call while an app is already initialized
  /// just returns the existing instance.
  Future<FirebaseApp> initialize() async {
    if (Firebase.apps.isNotEmpty) {
      return Firebase.app();
    }
    return Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  /// True once at least one Firebase app has been initialized.
  bool get isInitialized => Firebase.apps.isNotEmpty;

  /// Confirms the Auth SDK is configured for the current app. Accessing
  /// this instance performs no network call.
  FirebaseAuth get auth => FirebaseAuth.instance;

  /// Confirms the Firestore SDK is configured for the current app.
  /// Accessing this instance performs no network call and reads/writes no
  /// document.
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
}
