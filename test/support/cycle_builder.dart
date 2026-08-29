import 'package:rise/domain/models/cycle.dart';
import 'package:rise/domain/models/day_entry.dart';
import 'package:rise/domain/models/signs.dart';

/// Builds a cycle from a temperature series (indexed by cycle day minus one) for
/// engine tests. Day 1 is marked as menstruation so it also reads as a start.
Cycle buildCycle({
  required List<double?> temperatures,
  Map<int, CervicalMucus> mucus = const {},
  bool isCurrent = false,
}) {
  final base = DateTime(2026, 1, 1);
  final days = <DayEntry>[
    for (var i = 0; i < temperatures.length; i++)
      DayEntry(
        date: base.add(Duration(days: i)),
        temperature: temperatures[i],
        menstruation: i == 0 ? Menstruation.medium : Menstruation.none,
        mucus: mucus[i + 1] ?? CervicalMucus.none,
      ),
  ];
  return Cycle(days: days, isCurrent: isCurrent);
}

/// A textbook biphasic series: [lowDays] low measurements then a clear rise.
/// With the defaults the shift is detectable with ovulation on cycle day
/// [lowDays] and the coverline at [low].
List<double?> biphasic({
  required int lowDays,
  int highDays = 4,
  double low = 36.40,
  double high = 36.75,
}) {
  return [
    for (var i = 0; i < lowDays; i++) low,
    for (var i = 0; i < highDays; i++) high,
  ];
}
