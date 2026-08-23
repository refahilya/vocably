import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/role.dart';

/// Typed shape of a `users/{uid}` Firestore document.
///
/// Field presence mirrors DATA_MODEL.md §1 and `firestore.rules` exactly:
/// `cefrLevel` / `placementTestCompleted` / `placementTestPrompted` only
/// exist on `siswa` documents; `teacherCodeInput` only exists on `guru`
/// documents. Do not assume any of these are present for the other role.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    this.cefrLevel,
    this.placementTestCompleted,
    this.placementTestPrompted,
    this.teacherCodeInput,
  });

  final String uid;
  final String email;
  final String name;

  /// One of [Role.siswa] or [Role.guru].
  final String role;
  final DateTime createdAt;

  /// Siswa-only. Always absent on guru documents.
  final String? cefrLevel;

  /// Siswa-only. Always absent on guru documents.
  final bool? placementTestCompleted;

  /// Siswa-only. Always absent on guru documents.
  final bool? placementTestPrompted;

  /// Guru-only. Always absent on siswa documents. Stored permanently as an
  /// audit trail — see DATA_MODEL.md §1.
  final String? teacherCodeInput;

  bool get isStudent => role == Role.siswa;
  bool get isTeacher => role == Role.guru;

  factory AppUser.fromFirestore(Map<String, dynamic> data) {
    final createdAtRaw = data['createdAt'];
    return AppUser(
      uid: data['uid'] as String,
      email: data['email'] as String,
      name: data['name'] as String,
      role: data['role'] as String,
      createdAt: createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : DateTime.now(),
      cefrLevel: data['cefrLevel'] as String?,
      placementTestCompleted: data['placementTestCompleted'] as bool?,
      placementTestPrompted: data['placementTestPrompted'] as bool?,
      teacherCodeInput: data['teacherCodeInput'] as String?,
    );
  }

  /// Data for a brand-new student document. Must match the `create` rule's
  /// student branch in `firestore.rules` exactly (field set + values).
  static Map<String, dynamic> newStudentData({
    required String uid,
    required String email,
    required String name,
  }) {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': Role.siswa,
      'createdAt': FieldValue.serverTimestamp(),
      'cefrLevel': null,
      'placementTestCompleted': false,
      'placementTestPrompted': false,
    };
  }

  /// Data for a brand-new teacher document. Must match the `create` rule's
  /// teacher branch in `firestore.rules` exactly (field set + values).
  static Map<String, dynamic> newTeacherData({
    required String uid,
    required String email,
    required String name,
    required String teacherCodeInput,
  }) {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': Role.guru,
      'createdAt': FieldValue.serverTimestamp(),
      'teacherCodeInput': teacherCodeInput,
    };
  }
}
