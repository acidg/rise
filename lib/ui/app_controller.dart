import 'dart:math';

import 'package:flutter/material.dart';

import '../ble/measurement.dart';
import '../ble/thermometer_service.dart';
import '../data/entry_repository.dart';
import '../data/paired_device_store.dart';
import '../domain/fertility/cycle_analysis.dart';
import '../domain/fertility/fertility_window.dart';
import '../domain/models/cycle.dart';
import '../domain/models/day_entry.dart';
import 'chart/chart_day.dart';

/// Holds the loaded chart data and app-wide settings, and mediates edits and
/// device syncs. A [ChangeNotifier] so screens rebuild on change; its
/// collaborators are all interfaces, so it can be driven by fakes in tests.
class AppController extends ChangeNotifier {
  final EntryRepository repository;
  final ThermometerService thermometer;
  final PairedDeviceStore pairedDeviceStore;
  final CycleAnalysis analysis;

  AppController({
    required this.repository,
    required this.thermometer,
    PairedDeviceStore? pairedDeviceStore,
    this.analysis = const CycleAnalysis(),
  }) : pairedDeviceStore = pairedDeviceStore ?? InMemoryPairedDeviceStore();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  List<ChartDay> _days = const [];
  List<ChartDay> get days => _days;

  DiscoveredThermometer? _pairedDevice;
  DiscoveredThermometer? get pairedDevice => _pairedDevice;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Load entries, the remembered paired device, and compute the chart days.
  Future<void> load() async {
    final entries = await repository.loadAll();
    _days = _buildChartDays(entries);
    _pairedDevice = await pairedDeviceStore.load();
    _loaded = true;
    notifyListeners();
  }

  /// Remember [device] as the paired thermometer, persisting it across launches.
  Future<void> rememberPairedDevice(DiscoveredThermometer device) async {
    await pairedDeviceStore.save(device);
    _pairedDevice = device;
    notifyListeners();
  }

  /// Forget the paired thermometer. The operating system keeps the BLE bond, so
  /// re-pairing does not require entering the passkey again.
  Future<void> forgetPairedDevice() async {
    await pairedDeviceStore.clear();
    _pairedDevice = null;
    notifyListeners();
  }

  /// Persist an edited [entry] and refresh the chart.
  Future<void> saveEntry(DayEntry entry) async {
    await repository.save(entry);
    await load();
  }

  /// Fold synced [measurements] into day entries and refresh the chart,
  /// preserving any signs the user already logged for those days. Basal
  /// temperature is a single morning reading, so if the device returns more than
  /// one measurement for a day the earliest is kept.
  Future<void> importMeasurements(List<Measurement> measurements) async {
    if (measurements.isEmpty) {
      return;
    }
    final existing = {
      for (final entry in await repository.loadAll()) _dateKey(entry.date): entry,
    };
    final byDay = <DateTime, Measurement>{};
    for (final measurement in measurements) {
      final day = _dateKey(measurement.timestamp);
      final current = byDay[day];
      if (current == null || measurement.timestamp.isBefore(current.timestamp)) {
        byDay[day] = measurement;
      }
    }
    for (final MapEntry(key: day, value: measurement) in byDay.entries) {
      final base = existing[day] ?? DayEntry(date: day);
      await repository.save(base.copyWith(temperature: measurement.celsius));
    }
    await load();
  }

  static DateTime _dateKey(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  List<ChartDay> _buildChartDays(List<DayEntry> entries) {
    final result = <ChartDay>[];
    for (final analyzed in analysis.analyze(entries)) {
      final window = analyzed.window;
      final cycle = analyzed.cycle;
      final days = cycle.days;
      for (var i = 0; i < days.length; i++) {
        final cycleDay = i + 1;
        // The reference lines start at the six low measurements (ovulation day
        // minus five) and run to the end of the fertile window, where the
        // temperature shift closes it. They must not spread past the window.
        final onShiftBand =
            window.confirmed &&
            cycleDay >= window.ovulationDay - 5 &&
            cycleDay <= window.lastFertileDay;
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
            isToday: cycle.isCurrent && i == days.length - 1,
          ),
        );
      }
      if (cycle.isCurrent) {
        result.addAll(_futureDays(cycle, window, days.length));
      }
    }
    return result;
  }

  /// Predicted days past today for the current cycle: empty slots that extend to
  /// the end of the predicted fertile window (plus a small margin), so the
  /// prediction is visible ahead of today.
  List<ChartDay> _futureDays(
    Cycle cycle,
    FertilityWindow window,
    int recorded,
  ) {
    final predictedEnd = max(window.lastFertileDay, window.ovulationDay + 1);
    final horizon = max(predictedEnd + 2, recorded + 3);
    return [
      for (var cycleDay = recorded + 1; cycleDay <= horizon; cycleDay++)
        ChartDay(
          entry: DayEntry(
            date: cycle.startDate.add(Duration(days: cycleDay - 1)),
          ),
          cycleDay: cycleDay,
          fertile: window.isFertile(cycleDay),
          isOvulation: cycleDay == window.ovulationDay,
          confirmed: window.confirmed,
          coverline: null,
          lowestHigherTemperature: null,
          isFuture: true,
        ),
    ];
  }
}
