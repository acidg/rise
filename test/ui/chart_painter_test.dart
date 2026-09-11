import 'package:flutter_test/flutter_test.dart';
import 'package:rise/ui/chart/chart_painter.dart';

void main() {
  test('only the columns in the viewport are drawn, plus a small margin', () {
    // A 440 px viewport shows ten columns; scrolled to the 100th day.
    final range = visibleColumns(1200, 100 * kColumnWidth, 440);

    expect(range.first, 98);
    expect(range.last, 112);
  });

  test('the range is clamped to the history at both ends', () {
    final atStart = visibleColumns(1200, 0, 440);
    final atEnd = visibleColumns(1200, 1190 * kColumnWidth, 440);

    expect(atStart.first, 0);
    expect(atEnd.last, 1199);
  });

  test('an empty history yields an empty range', () {
    final range = visibleColumns(0, 0, 440);

    expect(range.last, lessThan(range.first));
  });

  test('a year boundary is the first column of a new calendar year', () {
    expect(startsYear(DateTime(2026, 1, 1), DateTime(2025, 12, 31)), isTrue);
    expect(startsYear(DateTime(2026, 1, 2), DateTime(2026, 1, 1)), isFalse);
  });

  test('the first column of the chart is not a year boundary', () {
    expect(startsYear(DateTime(2026, 1, 1), null), isFalse);
  });

  test(
    'a gap that skips new year still marks the first day recorded after it',
    () {
      // Calendar gaps are filled before the chart is built, but a record that
      // resumes mid-January must still show where the year turned.
      expect(startsYear(DateTime(2026, 1, 14), DateTime(2025, 11, 30)), isTrue);
    },
  );
}
