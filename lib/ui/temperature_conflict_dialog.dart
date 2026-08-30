import 'package:flutter/material.dart';

import 'app_controller.dart';

/// Ask the user whether a synced reading should overwrite the temperature
/// already stored for its day. Returns false (keep the stored value) when the
/// dialog is dismissed, so a reading is never overwritten without an explicit
/// yes. Suitable as a [TemperatureConflictResolver] once bound to a context.
Future<bool> confirmTemperatureOverwrite(
  BuildContext context,
  TemperatureConflict conflict,
) async {
  final materialLocalizations = MaterialLocalizations.of(context);
  final existingAt = conflict.existingAt;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Overwrite temperature?'),
      content: Text(
        'On ${materialLocalizations.formatMediumDate(conflict.day)} '
        'you already have ${_formatTemperature(conflict.existing)}'
        '${existingAt == null ? '' : ' at ${_formatTime(context, existingAt)}'} '
        'recorded. The thermometer reported '
        '${_formatTemperature(conflict.incoming)} at '
        '${_formatTime(context, conflict.incomingAt)}.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep existing'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Overwrite'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

String _formatTemperature(double celsius) => '${celsius.toStringAsFixed(2)} °C';

String _formatTime(BuildContext context, DateTime at) =>
    MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(at));
