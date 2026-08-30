import 'package:flutter_test/flutter_test.dart';
import 'package:rise/domain/models/day_entry.dart';
import 'package:rise/domain/models/signs.dart';
import 'package:rise/domain/fertility/cycle_analysis.dart';

void main() {
  test(
    'missing calendar days are filled so a cycle day equals the calendar offset',
    () {
      final entries = [
        DayEntry(
          date: DateTime(2026, 1, 1),
          temperature: 36.50,
          menstruation: Menstruation.medium,
        ),
        DayEntry(date: DateTime(2026, 1, 2), temperature: 36.52),
        // Jan 3 through Jan 9 were never recorded (device unused).
        DayEntry(date: DateTime(2026, 1, 10), temperature: 36.70),
      ];

      final analyzed = const CycleAnalysis().analyze(entries);

      expect(analyzed, hasLength(1));
      final days = analyzed.single.cycle.days;
      // Jan 1 through Jan 10 inclusive: ten day-continuous columns.
      expect(days, hasLength(10));
      expect(days.first.date, DateTime(2026, 1, 1));
      expect(days.last.date, DateTime(2026, 1, 10));
      // The gap is real empty days, not skipped.
      expect(days[4].date, DateTime(2026, 1, 5));
      expect(days[4].temperature, isNull);
      // The third recorded measurement now sits on cycle day 10, not day 3.
      expect(days[9].temperature, 36.70);
    },
  );

  test('a gap without a new period stays a single cycle', () {
    final entries = [
      DayEntry(
        date: DateTime(2026, 1, 1),
        temperature: 36.50,
        menstruation: Menstruation.medium,
      ),
      // Months later, still no fresh bleeding logged.
      DayEntry(date: DateTime(2026, 6, 1), temperature: 36.60),
    ];

    final analyzed = const CycleAnalysis().analyze(entries);

    expect(analyzed, hasLength(1));
    expect(analyzed.single.cycle.days.first.date, DateTime(2026, 1, 1));
    expect(analyzed.single.cycle.days.last.date, DateTime(2026, 6, 1));
  });
}
