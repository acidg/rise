import 'package:flutter/material.dart';

import '../../ble/thermometer_service.dart';
import '../app_controller.dart';

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
          DevicePairingSection(thermometer: controller.thermometer),
        ],
      ),
    );
  }
}

enum _PairState { idle, scanning, selecting, paired }

/// Drives the scan / pair / sync flow through the [ThermometerService]
/// interface, so it works with the fake and the real BLE implementation alike.
class DevicePairingSection extends StatefulWidget {
  final ThermometerService thermometer;

  const DevicePairingSection({super.key, required this.thermometer});

  @override
  State<DevicePairingSection> createState() => _DevicePairingSectionState();
}

class _DevicePairingSectionState extends State<DevicePairingSection> {
  _PairState _state = _PairState.idle;
  List<DiscoveredThermometer> _found = const [];
  DiscoveredThermometer? _paired;
  int? _batteryPercent;

  Future<void> _scan() async {
    setState(() => _state = _PairState.scanning);
    final devices = await widget.thermometer.scan().first;
    if (!mounted) {
      return;
    }
    setState(() {
      _found = devices;
      _state = _PairState.selecting;
    });
  }

  Future<void> _pair(DiscoveredThermometer device) async {
    final pin = await _askPin();
    if (pin == null) {
      return;
    }
    await widget.thermometer.pair(device, pin);
    if (!mounted) {
      return;
    }
    setState(() {
      _paired = device;
      _state = _PairState.paired;
    });
  }

  Future<void> _sync() async {
    final device = _paired;
    if (device == null) {
      return;
    }
    final result = await widget.thermometer.sync(device);
    if (!mounted) {
      return;
    }
    setState(() => _batteryPercent = result.batteryPercent);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Synced ${result.measurements.length} measurements'),
      ),
    );
  }

  Future<String?> _askPin() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter device PIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(hintText: '6-digit PIN on display'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Pair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _PairState.idle => _idle(),
      _PairState.scanning => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
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
      ),
      _PairState.selecting => _selecting(),
      _PairState.paired => _pairedCard(),
    };
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

  Widget _pairedCard() {
    final device = _paired!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.name, style: Theme.of(context).textTheme.titleMedium),
            Text(device.id, style: Theme.of(context).textTheme.bodySmall),
            if (_batteryPercent != null) ...[
              const SizedBox(height: 8),
              Text('Battery: $_batteryPercent%'),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(onPressed: _sync, child: const Text('Sync now')),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _paired = null;
                    _state = _PairState.idle;
                  }),
                  child: const Text('Forget'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
