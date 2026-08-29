import 'package:flutter_test/flutter_test.dart';
import 'package:vocably/utils/target_word_constants.dart';

void main() {
  test('kNoEndDate is a far-future sentinel, not null', () {
    expect(kNoEndDate.toDate().isAfter(DateTime(2050)), isTrue);
  });

  test('kAllStudents is a stable, non-empty sentinel string', () {
    expect(kAllStudents, isNotEmpty);
    expect(kAllStudents, '__all__');
  });
}
