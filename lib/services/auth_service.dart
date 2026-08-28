import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_service.dart';

/// Thin wrapper around Firebase Auth. Per CLAUDE.md §4, every Firebase call
/// goes through `services/`, never directly from widgets/providers.
class AuthService {
  AuthService([FirebaseService? firebaseService])
    : _firebaseService = firebaseService ?? const FirebaseService();

  final FirebaseService _firebaseService;

  FirebaseAuth get _auth => _firebaseService.auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  /// The signed-in user's Firebase ID token, or `null` if signed out.
  /// Used to authenticate calls to the Cloudflare Worker AI proxy
  /// (`AiWorkerService`) — `DATA_MODEL.md` §10.1: every Worker endpoint
  /// verifies this token manually (no Firebase Admin SDK in the Workers
  /// runtime).
  Future<String?> getIdToken() => _auth.currentUser?.getIdToken() ?? Future.value(null);

  /// Deletes the currently signed-in user.
  ///
  /// Used only to roll back a sign-up attempt whose Firestore profile
  /// write was rejected for a *confirmed* reason (an invalid/inactive
  /// teacher access code — see `SignUpController`), so no orphaned
  /// Auth-only account is left behind. Never called for uncertain/
  /// transient failures.
  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }
}
