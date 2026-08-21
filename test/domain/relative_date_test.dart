import 'package:flutter_test/flutter_test.dart';
import 'package:long_term_reminder/domain/format/relative_date.dart';

void main() {
  group('RelativeDateFormatter.dueLine', () {
    test('future date under 60 days uses day-count phrasing', () {
      final line = RelativeDateFormatter.dueLine(DateTime(2027, 7, 2), DateTime(2027, 6, 20));
      expect(line, 'Due in 12 days · Jul 2');
    });

    test('future date 60+ days out switches to month-count phrasing', () {
      final line = RelativeDateFormatter.dueLine(DateTime(2026, 12, 12), DateTime(2026, 8, 12));
      expect(line, contains('months'));
      expect(line, contains('Dec 12'));
    });

    test('past date reads "Was due N days ago"', () {
      final line = RelativeDateFormatter.dueLine(DateTime(2027, 1, 1), DateTime(2027, 1, 7));
      expect(line, 'Was due 6 days ago');
    });

    test('due exactly today reads "Due today"', () {
      final line = RelativeDateFormatter.dueLine(DateTime(2027, 1, 1), DateTime(2027, 1, 1));
      expect(line, 'Due today');
    });
  });
}
