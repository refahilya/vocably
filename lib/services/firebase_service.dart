import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Thin wrapper around Firebase SDK instance access.
///
/// Per CLAUDE.md §4, every call to Firebase must go through a `services/`
/// layer rather than being made directly from widgets/providers.
///
/// Bootstrapping (`Firebase.initializeApp`) happens once in `main.dart`,
/// before `runApp` — not here. This class only exposes the already-
/// initialized SDK singletons for other services (`AuthService`,
/// `UserService`, ...) to build on.
class FirebaseService {
  const FirebaseService();

  /// True once at least one Firebase app has been initialized.
  bool get isInitialized => Firebase.apps.isNotEmpty;

  FirebaseAuth get auth => FirebaseAuth.instance;

  FirebaseFirestore get firestore => FirebaseFirestore.instance;
}
