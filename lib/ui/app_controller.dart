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
import 'cycle_status.dart';

/// Typical luteal phase length, used to predict the next period from ovulation.
const int _lutealLength = 14;

/// A synced reading that disagrees with a temperature already stored for its day.
/// Surfaced by [AppController.importMeasurements] so the caller can ask the user
/// whether to overwrite before the stored value is replaced.
class TemperatureConflict {
  /// The calendar day (local midnight) both readings belong to.
  final DateTime day;

  /// The temperature already stored for the day, and when it was taken (null if
  /// that moment was never recorded).
  final double existing;
  final DateTime? existingAt;

  /// The temperature the thermometer reported, and when it was taken.
  final double incoming;
  final DateTime incomingAt;

  const TemperatureConflict({
    required this.day,
    required this.existing,
    required this.existingAt,
    required this.incoming,
    required this.incomingAt,
  });
}

/// Decides whether a diverging synced reading should overwrite the stored one:
/// returns true to overwrite, false to keep the existing value.
typedef TemperatureConflictResolver =
    Future<bool> Function(TemperatureConflict conflict);

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

  CycleStatus _status = const CycleStatus.unknown();

  /// Summary of the current cycle for the title bar: cycle day, fertility phase,
  /// and the next expected event. Unknown when no cycle can be detected.
  CycleStatus get status => _status;

  /// Load entries, the remembered paired device, and compute the chart days.
  Future<void> load() async {
    final entries = await repository.loadAll();
    final analyzed = analysis.analyze(entries);
    _days = _buildChartDays(analyzed);
    _status = _computeStatus(analyzed);
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
  ///
  /// A day whose stored temperature differs from the synced one is a conflict:
  /// [resolveConflict] is consulted for each such day and the reading is written
  /// only if it returns true. Days with no stored temperature (or an identical
  /// one) are applied without asking. With no resolver, conflicting days are left
  /// untouched, so an existing value is never overwritten silently.
  Future<void> importMeasurements(
    List<Measurement> measurements, {
    TemperatureConflictResolver? resolveConflict,
  }) async {
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
    var changed = false;
    for (final MapEntry(key: day, value: measurement) in byDay.entries) {
      final base = existing[day] ?? DayEntry(date: day);
      if (!await _shouldApply(base, measurement, resolveConflict)) {
        continue;
      }
      await repository.save(
        base.copyWith(
          temperature: measurement.celsius,
          temperatureAt: measurement.timestamp,
        ),
      );
      changed = true;
    }
    if (changed) {
      await load();
    }
  }

  /// Whether [measurement] should overwrite [base]. A day with no stored
  /// temperature, or one that already matches, is applied outright; a divergent
  /// value is applied only when [resolveConflict] confirms it.
  Future<bool> _shouldApply(
    DayEntry base,
    Measurement measurement,
    TemperatureConflictResolver? resolveConflict,
  ) async {
    final stored = base.temperature;
    if (stored == null || stored == measurement.celsius) {
      return true;
    }
    if (resolveConflict == null) {
      return false;
    }
    return resolveConflict(
      TemperatureConflict(
        day: _dateKey(measurement.timestamp),
        existing: stored,
        existingAt: base.temperatureAt,
        incoming: measurement.celsius,
        incomingAt: measurement.timestamp,
      ),
    );
  }

  static DateTime _dateKey(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  List<ChartDay> _buildChartDays(List<AnalyzedCycle> analyzed) {
    final result = <ChartDay>[];
    for (final cycleWithWindow in analyzed) {
      final window = cycleWithWindow.window;
      final cycle = cycleWithWindow.cycle;
      final known = cycle.hasKnownStart;
      final days = cycle.days;
      for (var i = 0; i < days.length; i++) {
        final cycleDay = i + 1;
        // The reference lines start at the six low measurements (ovulation day
        // minus five) and run to the end of the fertile window, where the
        // temperature shift closes it. They must not spread past the window.
        final onShiftBand =
            known &&
            window.confirmed &&
            cycleDay >= window.ovulationDay - 5 &&
            cycleDay <= window.lastFertileDay;
        result.add(
          ChartDay(
            entry: days[i],
            cycleDay: known ? cycleDay : null,
            fertile: known && window.isFertile(cycleDay),
            isOvulation: known && cycleDay == window.ovulationDay,
            confirmed: known && window.confirmed,
            coverline: onShiftBand ? window.coverline : null,
            lowestHigherTemperature: onShiftBand
                ? window.lowestHigherTemperature
                : null,
            isToday: cycle.isCurrent && i == days.length - 1,
          ),
        );
      }
      // Predictions only make sense once a cycle start is known.
      if (cycle.isCurrent && known) {
        result.addAll(_futureDays(cycle, window, days.length));
      }
    }
    return result;
  }

  /// Derive the title-bar summary from the current (last) cycle. Unknown when
  /// there is no cycle, or the current run has no known start.
  CycleStatus _computeStatus(List<AnalyzedCycle> analyzed) {
    if (analyzed.isEmpty) {
      return const CycleStatus.unknown();
    }
    final current = analyzed.last;
    if (!current.cycle.hasKnownStart) {
      return const CycleStatus.unknown();
    }
    final day = current.cycle.length;
    final window = current.window;
    final phase = window.isFertile(day) ? CyclePhase.fertile : CyclePhase.infertile;

    final String nextEvent;
    if (day < window.ovulationDay) {
      nextEvent = _inDays('Ovulation', window.ovulationDay - day);
    } else {
      final untilPeriod = window.ovulationDay + _lutealLength - day;
      nextEvent = untilPeriod > 0 ? _inDays('Period', untilPeriod) : 'Period due';
    }
    return CycleStatus(cycleDay: day, phase: phase, nextEvent: nextEvent);
  }

  static String _inDays(String event, int days) =>
      '$event in ~$days ${days == 1 ? 'day' : 'days'}';

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
