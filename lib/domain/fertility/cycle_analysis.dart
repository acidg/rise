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
  List<AnalyzedCycle> analyze(List<DayEntry> entries) {
    final cycles = segmenter.segment(entries);
    final windows = analyzer.analyze(cycles);
    return [
      for (var i = 0; i < cycles.length; i++)
        AnalyzedCycle(cycles[i], windows[i]),
    ];
  }
}
