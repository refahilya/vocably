import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import 'firebase_service.dart';

/// Thin wrapper around Firestore `users/{uid}` reads/writes. Per
/// CLAUDE.md §4, every Firebase call goes through `services/`.
class UserService {
  UserService([FirebaseService? firebaseService])
    : _firebaseService = firebaseService ?? const FirebaseService();

  final FirebaseService _firebaseService;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firebaseService.firestore.collection('users');

  Future<AppUser?> fetchProfile(String uid) async {
    final snapshot = await _users.doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    return AppUser.fromFirestore(data);
  }

  /// Live view of a `users/{uid}` document. Used instead of [fetchProfile]
  /// by the root routing provider so that a profile created *after* the
  /// first read (e.g. moments after sign-up, or right after "complete
  /// registration") is picked up automatically — a one-shot fetch would
  /// otherwise cache a stale `null` and never notice.
  Stream<AppUser?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return AppUser.fromFirestore(data);
    });
  }

  Future<void> createStudentProfile({
    required String uid,
    required String email,
    required String name,
  }) {
    return _users
        .doc(uid)
        .set(AppUser.newStudentData(uid: uid, email: email, name: name));
  }

  Future<void> createTeacherProfile({
    required String uid,
    required String email,
    required String name,
    required String teacherCodeInput,
  }) {
    return _users.doc(uid).set(
      AppUser.newTeacherData(
        uid: uid,
        email: email,
        name: name,
        teacherCodeInput: teacherCodeInput,
      ),
    );
  }

  /// Flips `users/{uid}.placementTestPrompted` to `true` (`SPEC.md` §3.1,
  /// `DATA_MODEL.md` §1) — called exactly once, the moment the one-time
  /// automatic placement-test offer is shown, regardless of which choice
  /// the student makes. `firestore.rules`' siswa self-update whitelist
  /// already allows this field (Milestone 2); no rules change needed.
  Future<void> markPlacementTestPrompted(String uid) {
    return _users.doc(uid).update({'placementTestPrompted': true});
  }
}
