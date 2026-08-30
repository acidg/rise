import '../models/cycle.dart';
import '../models/day_entry.dart';
import 'cycle_segmenter.dart';
import 'fertility_window.dart';
import 'symptothermal_analyzer.dart';

/// A cycle paired with its computed fertile window.
class AnalyzedCycle {
  final Cycle cycle;
  final FertilityWindow window;

  const AnalyzedCycle(this.cycle, this.window);
}

/// Ties cycle segmentation and fertility analysis together for the UI. Both
/// collaborators are interfaces, so a screen can be tested with fakes.
class CycleAnalysis {
  final CycleSegmenter segmenter;
  final FertilityAnalyzer analyzer;

  const CycleAnalysis({
    this.segmenter = const MenstruationCycleSegmenter(),
    this.analyzer = const SensiplanAnalyzer(),
  });

  /// Segment [entries] (oldest-first) into cycles and compute each window.
  ///
  /// Gaps in the record are filled with empty days first, so a cycle day always
  /// equals the number of days since the cycle began. This keeps the Sensiplan
  /// rules (which count cycle days) correct across missing measurements and lets
  /// the chart render an unrecorded stretch as a real gap.
  List<AnalyzedCycle> analyze(List<DayEntry> entries) {
    final cycles = segmenter.segment(_fillCalendarGaps(entries));
    final windows = analyzer.analyze(cycles);
    return [
      for (var i = 0; i < cycles.length; i++)
        AnalyzedCycle(cycles[i], windows[i]),
    ];
  }
}

/// Insert an empty entry for every calendar day missing between the first and
/// last of [entries] (ordered oldest-first), so the sequence is day-continuous.
List<DayEntry> _fillCalendarGaps(List<DayEntry> entries) {
  if (entries.length < 2) {
    return entries;
  }
  final filled = <DayEntry>[entries.first];
  for (var i = 1; i < entries.length; i++) {
    final current = _dayStart(entries[i].date);
    var day = _nextDay(entries[i - 1].date);
    while (day.isBefore(current)) {
      filled.add(DayEntry(date: day));
      day = _nextDay(day);
    }
    filled.add(entries[i]);
  }
  return filled;
}

/// Local midnight of [date]; also the safe way to step by whole calendar days
/// across daylight-saving changes.
DateTime _dayStart(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _nextDay(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1);
