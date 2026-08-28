/// The six CEFR levels used throughout the app (`SPEC.md` §3.2/§3.3,
/// `DATA_MODEL.md` §2) — shared between the student vocab browser's level
/// selector and the guru "Tambah Kosakata" form (Milestone 5) so both
/// stay in sync with exactly one list. `C2` is always a valid choice even
/// though the current Oxford-sourced data has no C2 entries yet — see
/// `CLAUDE.md` §8 "Level CEFR".
const List<String> kCefrLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
