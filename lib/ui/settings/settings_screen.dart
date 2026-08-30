import 'dart:async';

import 'package:flutter/material.dart';

import '../../ble/thermometer_service.dart';
import '../app_controller.dart';
import '../temperature_conflict_dialog.dart';
import 'data_section.dart';

/// Settings: appearance (theme) and thermometer pairing.
class SettingsScreen extends StatelessWidget {
  final AppController controller;

  const SettingsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {controller.themeMode},
              onSelectionChanged: (selection) =>
                  controller.setThemeMode(selection.first),
            ),
          ),
          const SizedBox(height: 28),
          Text('Thermometer', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DevicePairingSection(controller: controller),
          const SizedBox(height: 28),
          Text('Data', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DataSection(controller: controller),
        ],
      ),
    );
  }
}

/// Transient state of the scan flow. The paired device itself lives in the
/// [AppController] so it persists across launches, so there is no "paired" state
/// here: the paired card shows whenever the controller has a remembered device.
enum _PairState { idle, scanning, selecting }

/// Drives the scan / pair / sync flow through the [AppController], which owns the
/// [ThermometerService] and the persisted paired device, so it works with the
/// fake and the real BLE implementation alike.
class DevicePairingSection extends StatefulWidget {
  final AppController controller;

  const DevicePairingSection({super.key, required this.controller});

  @override
  State<DevicePairingSection> createState() => _DevicePairingSectionState();
}

class _DevicePairingSectionState extends State<DevicePairingSection> {
  _PairState _state = _PairState.idle;
  List<DiscoveredThermometer> _found = const [];
  StreamSubscription<List<DiscoveredThermometer>>? _scanSub;

  ThermometerService get _thermometer => widget.controller.thermometer;
  ThermometerStatus get _status => widget.controller.thermometerStatus;
  bool get _connected => _status.connected;
  bool get _syncing => widget.controller.isSyncing;

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _state = _PairState.scanning;
      _found = const [];
    });
    // The scan emits the growing list of devices as they advertise, so listen
    // rather than take the first (empty) emission; the stream ends when the scan
    // times out.
    _scanSub?.cancel();
    _scanSub = _thermometer.scan().listen(
      (devices) {
        if (!mounted) {
          return;
        }
        setState(() {
          _found = devices;
          // Keep showing the searching spinner until a device actually appears;
          // the results stream emits an empty list first while the scan runs.
          if (devices.isNotEmpty) {
            _state = _PairState.selecting;
          }
        });
      },
      onError: (Object error) {
        if (mounted) {
          setState(() => _state = _PairState.selecting);
          _showError(error);
        }
      },
      onDone: () {
        if (mounted && _state == _PairState.scanning) {
          setState(() => _state = _PairState.selecting);
        }
      },
      cancelOnError: true,
    );
  }

  Future<void> _pair(DiscoveredThermometer device) async {
    // Stop the discovery scan so the pairing connect can own the radio.
    await _scanSub?.cancel();
    if (!mounted) {
      return;
    }
    // Bonding is driven by the platform: a system pairing dialog appears and the
    // thermometer shows a six-digit passkey to type into it. Hint at that first,
    // since the app cannot collect the passkey itself.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Confirm pairing in the system dialog, entering the code shown on the thermometer.',
        ),
      ),
    );
    try {
      await _thermometer.pair(device);
    } on Object catch (error) {
      if (mounted) {
        _showError(error);
      }
      return;
    }
    await widget.controller.rememberPairedDevice(device);
    if (!mounted) {
      return;
    }
    setState(() => _state = _PairState.idle);
  }

  Future<void> _sync() async {
    try {
      final count = await widget.controller.sync(
        resolveConflict: (conflict) =>
            confirmTemperatureOverwrite(context, conflict),
      );
      if (!mounted || count == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Synced $count measurements')),
      );
    } on Object catch (error) {
      if (mounted) {
        _showError(error);
      }
    }
  }

  Future<void> _forget() async {
    await widget.controller.forgetPairedDevice();
    if (mounted) {
      setState(() => _state = _PairState.idle);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when the persisted paired device changes, so the paired card
    // appears after pairing and after a restart, and disappears on forget.
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final paired = widget.controller.pairedDevice;
        return switch (_state) {
          _PairState.scanning => _scanning(),
          _PairState.selecting => _selecting(),
          _PairState.idle => paired != null ? _pairedCard(paired) : _idle(),
        };
      },
    );
  }

  Widget _scanning() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Searching for thermometers…'),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Press the button on your thermometer to wake it.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _idle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('No thermometer paired.'),
        const SizedBox(height: 8),
        FilledButton(onPressed: _scan, child: const Text('Pair device')),
      ],
    );
  }

  Widget _selecting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final device in _found)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(device.name),
            subtitle: Text(device.id),
            trailing: FilledButton(
              onPressed: () => _pair(device),
              child: const Text('Pair'),
            ),
          ),
        TextButton(onPressed: _scan, child: const Text('Rescan')),
      ],
    );
  }

  Widget _pairedCard(DiscoveredThermometer device) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    device.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _connectionChip(),
              ],
            ),
            Text(device.id, style: Theme.of(context).textTheme.bodySmall),
            // The battery reading is known only while connected.
            if (_connected && _status.batteryPercent != null) ...[
              const SizedBox(height: 10),
              _batteryBar(_status.batteryPercent!),
            ],
            if (!_connected && !_syncing) ...[
              const SizedBox(height: 8),
              Text(
                'Press the button on your thermometer to wake it; it connects '
                'automatically and stays connected.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                // Sync is available only over an open connection.
                if (_connected || _syncing)
                  FilledButton(
                    onPressed: _syncing || !_connected ? null : _sync,
                    child: _syncing
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Syncing…'),
                            ],
                          )
                        : const Text('Sync now'),
                  ),
                if (_connected || _syncing) const SizedBox(width: 8),
                TextButton(
                  onPressed: _syncing ? null : _forget,
                  child: const Text('Forget'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Battery level as a coloured progress bar with a percentage, matching the
  /// mock: green above 50%, amber above 20%, red below.
  Widget _batteryBar(int percent) {
    final color = percent > 50
        ? const Color(0xFF2FAE7A)
        : percent > 20
        ? const Color(0xFFF0A641)
        : const Color(0xFFE5544E);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 7,
              color: color,
              backgroundColor: Theme.of(context).dividerColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$percent%',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// A dot, label, and signal-strength icon showing whether the maintained
  /// connection to the thermometer is currently up.
  Widget _connectionChip() {
    final color = _connected ? Colors.green : Theme.of(context).disabledColor;
    final rssi = _status.rssi;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          _connected ? 'Connected' : 'Waiting…',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_connected && rssi != null) ...[
          const SizedBox(width: 6),
          Icon(_signalIcon(rssi), size: 16, color: color),
          const SizedBox(width: 2),
          Text('$rssi dBm', style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }

  /// Pick a signal-strength icon from the RSSI: stronger (closer to 0) is more
  /// bars. Typical BLE ranges from about -40 dBm (very close) to -100 (far).
  IconData _signalIcon(int rssi) {
    if (rssi >= -60) {
      return Icons.signal_cellular_alt;
    }
    if (rssi >= -75) {
      return Icons.signal_cellular_alt_2_bar;
    }
    return Icons.signal_cellular_alt_1_bar;
  }
}
