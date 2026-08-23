/// Canonical role constants for `users.role`.
///
/// Kept as named constants (per CLAUDE.md §4's rule against scattering
/// sentinel/enum-like literals) so the string values live in exactly one
/// place, mirrored by `firestore.rules` and `DATA_MODEL.md` §1.
abstract final class Role {
  static const String siswa = 'siswa';
  static const String guru = 'guru';
}
