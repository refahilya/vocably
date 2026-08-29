import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/utils/session_date_format.dart';

void main() {
  test('formats as d/M/yyyy HH:mm (DESIGN_REFERENCE.md §3.3)', () {
    final dateTime = DateTime(2026, 8, 28, 14, 5);
    expect(formatSessionTimestamp(dateTime), '28/8/2026 14:05');
  });

  test('does not zero-pad day/month, but does zero-pad hour/minute', () {
    final dateTime = DateTime(2026, 1, 2, 9, 3);
    expect(formatSessionTimestamp(dateTime), '2/1/2026 09:03');
  });
}
