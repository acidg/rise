import '../models/cycle.dart';
import '../models/day_entry.dart';
import '../models/signs.dart';

/// Splits a chronological list of day entries into cycles.
abstract interface class CycleSegmenter {
  /// [days] must be ordered oldest-first. Returns cycles oldest-first; the last
  /// cycle is marked current.
  List<Cycle> segment(List<DayEntry> days);
}

/// Starts a new cycle on each menstruation onset: the first day of real bleeding
/// (light or heavier) that follows a day without such bleeding. Spotting does
/// not start a cycle, so mid-cycle or premenstrual spotting is ignored.
class MenstruationCycleSegmenter implements CycleSegmenter {
  const MenstruationCycleSegmenter();

  @override
  List<Cycle> segment(List<DayEntry> days) {
    if (days.isEmpty) {
      return const [];
    }

    final starts = <int>[];
    for (var i = 0; i < days.length; i++) {
      if (!days[i].menstruation.isFlow) {
        continue;
      }
      if (i == 0 || !days[i - 1].menstruation.isFlow) {
        starts.add(i);
      }
    }
    // Keep any days logged before the first period as a leading partial cycle so
    // no data is dropped.
    if (starts.isEmpty || starts.first != 0) {
      starts.insert(0, 0);
    }

    final cycles = <Cycle>[];
    for (var s = 0; s < starts.length; s++) {
      final from = starts[s];
      final to = s + 1 < starts.length ? starts[s + 1] : days.length;
      cycles.add(
        Cycle(days: days.sublist(from, to), isCurrent: s == starts.length - 1),
      );
    }
    return cycles;
  }
}
