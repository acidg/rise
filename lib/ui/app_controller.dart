import 'package:flutter/material.dart';

import '../ble/thermometer_service.dart';
import '../data/entry_repository.dart';
import '../domain/fertility/cycle_analysis.dart';
import '../domain/models/day_entry.dart';
import 'chart/chart_day.dart';

/// Holds the loaded chart data and app-wide settings, and mediates edits and
/// device syncs. A [ChangeNotifier] so screens rebuild on change; its
/// collaborators are all interfaces, so it can be driven by fakes in tests.
class AppController extends ChangeNotifier {
  final EntryRepository repository;
  final ThermometerService thermometer;
  final CycleAnalysis analysis;

  AppController({
    required this.repository,
    required this.thermometer,
    this.analysis = const CycleAnalysis(),
  });

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  List<ChartDay> _days = const [];
  List<ChartDay> get days => _days;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Load entries and compute the chart days.
  Future<void> load() async {
    final entries = await repository.loadAll();
    _days = _buildChartDays(entries);
    _loaded = true;
    notifyListeners();
  }

  /// Persist an edited [entry] and refresh the chart.
  Future<void> saveEntry(DayEntry entry) async {
    await repository.save(entry);
    await load();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  List<ChartDay> _buildChartDays(List<DayEntry> entries) {
    final result = <ChartDay>[];
    for (final analyzed in analysis.analyze(entries)) {
      final window = analyzed.window;
      final days = analyzed.cycle.days;
      for (var i = 0; i < days.length; i++) {
        final cycleDay = i + 1;
        // The reference lines sit on the shift band: the six low measurements
        // (ovulation day minus five through ovulation) and the three higher ones
        // that confirm it (through ovulation day plus three).
        final onShiftBand =
            window.confirmed &&
            cycleDay >= window.ovulationDay - 5 &&
            cycleDay <= window.ovulationDay + 3;
        result.add(
          ChartDay(
            entry: days[i],
            cycleDay: cycleDay,
            fertile: window.isFertile(cycleDay),
            isOvulation: cycleDay == window.ovulationDay,
            confirmed: window.confirmed,
            coverline: onShiftBand ? window.coverline : null,
            lowestHigherTemperature: onShiftBand
                ? window.lowestHigherTemperature
                : null,
          ),
        );
      }
    }
    return result;
  }
}
