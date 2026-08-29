import 'package:intl/intl.dart';

/// `DESIGN_REFERENCE.md` §3.3's exact format for Riwayat "Per Sesi" cards:
/// `d/M/yyyy HH:mm`. Kept as one named formatter here (rather than
/// scattering `DateFormat('d/M/yyyy HH:mm')` at call sites) so the pattern
/// only has to match the design doc in one place.
final DateFormat _sessionCardFormat = DateFormat('d/M/yyyy HH:mm');

/// Formats [dateTime] for a session history card, e.g. `28/8/2026 14:05`.
String formatSessionTimestamp(DateTime dateTime) => _sessionCardFormat.format(dateTime);
