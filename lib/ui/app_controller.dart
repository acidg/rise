import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../ble/measurement.dart';
import '../ble/thermometer_service.dart';
import '../data/day_entry_csv.dart';
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

/// An imported day that already exists in the history with different contents.
/// Surfaced by [AppController.importCsv] so the caller can ask the user whether
/// the imported entry should replace the stored one.
class EntryConflict {
  /// The entry currently stored for the day.
  final DayEntry existing;

  /// The entry read from the imported file, for the same calendar day.
  final DayEntry incoming;

  const EntryConflict({required this.existing, required this.incoming});

  /// The calendar day (local midnight) both entries belong to.
  DateTime get day => DateTime(
    existing.date.year,
    existing.date.month,
    existing.date.day,
  );
}

/// Decides whether an imported entry should replace the differing stored one:
/// returns true to replace, false to keep the existing entry.
typedef EntryConflictResolver = Future<bool> Function(EntryConflict conflict);

/// Outcome of an import: how many days were newly added, replaced an existing
/// (differing) day, or left unchanged because they matched or the user kept the
/// stored version.
class ImportResult {
  final int added;
  final int replaced;
  final int skipped;

  const ImportResult({
    this.added = 0,
    this.replaced = 0,
    this.skipped = 0,
  });

  int get total => added + replaced + skipped;
}

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

  /// The maintained connection to the paired thermometer, held open exactly
  /// while a device is remembered so a sync can run without scan/connect churn.
  ThermometerSession? _session;
  String? _sessionDeviceId;
  StreamSubscription<ThermometerStatus>? _statusSub;

  ThermometerStatus _thermometerStatus = const ThermometerStatus();

  /// Live status of the maintained connection to the paired thermometer:
  /// connected state, signal strength, and battery. Reset to disconnected when
  /// no device is paired.
  ThermometerStatus get thermometerStatus => _thermometerStatus;

  bool _syncing = false;

  /// Whether a sync is in progress. Screens observe this to show a spinner and
  /// disable their sync controls.
  bool get isSyncing => _syncing;

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
    _reconcileSession();
    notifyListeners();
  }

  /// Remember [device] as the paired thermometer, persisting it across launches.
  Future<void> rememberPairedDevice(DiscoveredThermometer device) async {
    await pairedDeviceStore.save(device);
    _pairedDevice = device;
    _reconcileSession();
    notifyListeners();
  }

  /// Forget the paired thermometer. The operating system keeps the BLE bond, so
  /// re-pairing does not require entering the passkey again.
  Future<void> forgetPairedDevice() async {
    await pairedDeviceStore.clear();
    _pairedDevice = null;
    _reconcileSession();
    notifyListeners();
  }

  /// Pull the history from the paired thermometer over the maintained
  /// connection and fold it into the day entries, asking [resolveConflict]
  /// before overwriting a diverging stored temperature. Returns the number of
  /// measurements read, or null when there is nothing to sync (no device, not
  /// connected, or a sync already running). Rethrows any transfer error so the
  /// caller can surface it; [isSyncing] is cleared either way.
  Future<int?> sync({TemperatureConflictResolver? resolveConflict}) async {
    final session = _session;
    if (session == null || !_thermometerStatus.connected || _syncing) {
      return null;
    }
    _syncing = true;
    notifyListeners();
    try {
      final result = await session.sync();
      await importMeasurements(
        result.measurements,
        resolveConflict: resolveConflict,
      );
      return result.measurements.length;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// Open, close, or re-point the maintained connection so it always tracks the
  /// currently paired device. A no-op when the session already targets that
  /// device, so the repeated [load] calls after an edit or sync never churn the
  /// connection.
  void _reconcileSession() {
    final device = _pairedDevice;
    if (device == null) {
      unawaited(_closeSession());
      return;
    }
    if (_session != null && _sessionDeviceId == device.id) {
      return;
    }
    unawaited(_openSession(device));
  }

  Future<void> _openSession(DiscoveredThermometer device) async {
    await _closeSession();
    final session = thermometer.openSession(device.id);
    _session = session;
    _sessionDeviceId = device.id;
    _statusSub = session.status.listen((status) {
      _thermometerStatus = status;
      notifyListeners();
    });
  }

  Future<void> _closeSession() async {
    await _statusSub?.cancel();
    _statusSub = null;
    final session = _session;
    _session = null;
    _sessionDeviceId = null;
    _thermometerStatus = const ThermometerStatus();
    await session?.close();
  }

  @override
  void dispose() {
    unawaited(_closeSession());
    super.dispose();
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

  /// Serialise the whole day history to CSV for the user to back up or move to
  /// another device. The paired thermometer is device-specific and is not part of
  /// the history, so it is never included.
  Future<String> exportCsv() async {
    final entries = await repository.loadAll();
    return DayEntryCsv.encode(entries);
  }

  /// Import day entries from a CSV document produced by [exportCsv] (or an
  /// equivalent spreadsheet export) and refresh the chart.
  ///
  /// A day absent from the history is added. A day whose imported entry matches
  /// the stored one is left untouched. A day that exists with different contents
  /// is a conflict: [resolveConflict] is consulted and the imported entry is
  /// written only if it returns true. With no resolver, conflicting days are kept
  /// as stored, so importing never overwrites diverging data silently.
  ///
  /// Throws [FormatException] when the CSV cannot be parsed (see
  /// [DayEntryCsv.decode]).
  Future<ImportResult> importCsv(
    String csv, {
    EntryConflictResolver? resolveConflict,
  }) async {
    final incoming = DayEntryCsv.decode(csv);
    if (incoming.isEmpty) {
      return const ImportResult();
    }
    final existing = {
      for (final entry in await repository.loadAll()) _dateKey(entry.date): entry,
    };
    var added = 0;
    var replaced = 0;
    var skipped = 0;
    for (final entry in incoming) {
      final stored = existing[_dateKey(entry.date)];
      if (stored == null) {
        await repository.save(entry);
        added++;
        continue;
      }
      if (stored == entry) {
        skipped++;
        continue;
      }
      final replace =
          resolveConflict != null &&
          await resolveConflict(
            EntryConflict(existing: stored, incoming: entry),
          );
      if (replace) {
        await repository.save(entry);
        replaced++;
      } else {
        skipped++;
      }
    }
    if (added > 0 || replaced > 0) {
      await load();
    }
    return ImportResult(added: added, replaced: replaced, skipped: skipped);
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
