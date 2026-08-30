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
///
/// A history can begin mid-cycle, so the days before the first onset are kept as
/// a leading run with an unknown start ([Cycle.hasKnownStart] false) rather than
/// being numbered from day one. When no bleeding is logged at all, the whole
/// record is one such unknown-start run.
class MenstruationCycleSegmenter implements CycleSegmenter {
  const MenstruationCycleSegmenter();

  @override
  List<Cycle> segment(List<DayEntry> days) {
    if (days.isEmpty) {
      return const [];
    }

    final onsets = <int>[];
    for (var i = 0; i < days.length; i++) {
      if (!days[i].menstruation.isFlow) {
        continue;
      }
      if (i == 0 || !days[i - 1].menstruation.isFlow) {
        onsets.add(i);
      }
    }

    if (onsets.isEmpty) {
      // No bleeding recorded: a single open run whose cycle start is unknown.
      return [Cycle(days: days, isCurrent: true, hasKnownStart: false)];
    }

    final cycles = <Cycle>[];
    // Days before the first onset belong to a cycle whose start we never saw.
    if (onsets.first != 0) {
      cycles.add(
        Cycle(days: days.sublist(0, onsets.first), hasKnownStart: false),
      );
    }
    for (var o = 0; o < onsets.length; o++) {
      final from = onsets[o];
      final to = o + 1 < onsets.length ? onsets[o + 1] : days.length;
      cycles.add(
        Cycle(days: days.sublist(from, to), isCurrent: o == onsets.length - 1),
      );
    }
    return cycles;
  }
}
