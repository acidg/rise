import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/day_entry.dart';
import '../../domain/models/signs.dart';
import '../sign_labels.dart';

const List<String> _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const double _defaultTemperature = 36.50;
const double _temperatureStep = 0.01;

/// Bottom sheet to review and edit a single day's entry. Calls [onSave] with the
/// updated entry and closes.
class DayDetailSheet extends StatefulWidget {
  final DayEntry entry;
  final ValueChanged<DayEntry> onSave;

  const DayDetailSheet({super.key, required this.entry, required this.onSave});

  @override
  State<DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<DayDetailSheet> {
  late final TextEditingController _temperatureController;
  TimeOfDay? _temperatureTime;
  late Menstruation _menstruation;
  late CervicalMucus _mucus;
  Cervix? _cervix;
  late Pain _pain;
  Mood? _mood;
  late Libido _libido;
  late Intercourse _intercourse;
  late final TextEditingController _notes;

  /// Whether the user changed anything. Edits are saved when the sheet closes
  /// (by button, drag, or tapping outside); an untouched sheet saves nothing, so
  /// merely viewing a day never writes a value.
  bool _dirty = false;

  /// Whether the temperature field itself was touched. Guards against writing the
  /// placeholder temperature to a day that only had other signs logged.
  bool _temperatureTouched = false;

  bool _persisted = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    // A day with no measurement shows a blank field, not a placeholder value.
    _temperatureController = TextEditingController(
      text: entry.temperature?.toStringAsFixed(2) ?? '',
    );
    final measuredAt = entry.temperatureAt;
    _temperatureTime = measuredAt == null
        ? null
        : TimeOfDay.fromDateTime(measuredAt);
    _menstruation = entry.menstruation;
    _mucus = entry.mucus;
    _cervix = entry.cervix;
    _pain = entry.pain;
    _mood = entry.mood;
    _libido = entry.libido;
    _intercourse = entry.intercourse;
    _notes = TextEditingController(text: entry.notes);
    _notes.addListener(_markDirty);
  }

  @override
  void dispose() {
    // Persist edits made when the sheet is dismissed without the Save button.
    _persist();
    _temperatureController.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _markDirty() => _dirty = true;

  /// The temperature currently parsed from the field, or null when the field is
  /// blank or holds an incomplete/unparseable entry.
  double? get _fieldTemperature =>
      double.tryParse(_temperatureController.text.replaceAll(',', '.'));

  /// Adjust the temperature by [delta] from the value currently shown, keeping it
  /// to two decimals. Stepping from a blank field seeds the default first, so the
  /// first press reveals a starting value rather than jumping past it.
  void _step(double delta) {
    final current = _fieldTemperature;
    final next = current == null
        ? _defaultTemperature
        : double.parse((current + delta).toStringAsFixed(2));
    setState(() {
      _temperatureController.text = next.toStringAsFixed(2);
      _dirty = true;
      _temperatureTouched = true;
    });
  }

  /// Build the entry from the current field values. The placeholder temperature
  /// is only written if the field was actually touched or the day already had a
  /// temperature, so saving a day edited for other signs does not invent one.
  DayEntry _edited() {
    final date = widget.entry.date;
    final time = _temperatureTime;
    final measuredAt = time == null
        ? null
        : DateTime(date.year, date.month, date.day, time.hour, time.minute);
    // Keep the day free of a temperature unless one is actually present: the
    // field was touched and holds a value, or the day already had a reading.
    final temperature = _fieldTemperature ?? widget.entry.temperature;
    final hasTemperature =
        _temperatureTouched || widget.entry.temperature != null;
    return widget.entry.copyWith(
      temperature: hasTemperature ? temperature : null,
      temperatureAt: measuredAt,
      menstruation: _menstruation,
      mucus: _mucus,
      cervix: _cervix,
      pain: _pain,
      mood: _mood,
      libido: _libido,
      intercourse: _intercourse,
      notes: _notes.text,
    );
  }

  /// Save the edits once. [force] saves even when nothing changed, for the
  /// explicit Save button; dismissal only saves when something changed.
  void _persist({bool force = false}) {
    if (_persisted || (!force && !_dirty)) {
      return;
    }
    _persisted = true;
    widget.onSave(_edited());
  }

  void _save() {
    _persist(force: true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.entry.date;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.day} ${_monthAbbr[date.month - 1]} ${date.year}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _temperatureField(context),
            _chips<Menstruation>(
              'Bleeding',
              Menstruation.values,
              _menstruation,
              (v) => v.label,
              (v) => setState(() => _menstruation = v),
            ),
            _chips<CervicalMucus>(
              'Cervical mucus',
              CervicalMucus.values,
              _mucus,
              (v) => v.label,
              (v) => setState(() => _mucus = v),
            ),
            _chips<Cervix>(
              'Cervix',
              Cervix.values,
              _cervix,
              (v) => v.label,
              (v) => setState(() => _cervix = v),
            ),
            _chips<Pain>(
              'Pain',
              Pain.values,
              _pain,
              (v) => v.label,
              (v) => setState(() => _pain = v),
            ),
            _chips<Mood>(
              'Mood',
              Mood.values,
              _mood,
              (v) => v.label,
              (v) => setState(() => _mood = v),
            ),
            _chips<Intercourse>(
              'Sex',
              Intercourse.values,
              _intercourse,
              (v) => v.label,
              (v) => setState(() => _intercourse = v),
            ),
            _chips<Libido>(
              'Libido',
              Libido.values,
              _libido,
              (v) => v.label,
              (v) => setState(() => _libido = v),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Notes'),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('Save')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _temperatureTime ?? TimeOfDay.now(),
      helpText: 'Measurement time',
    );
    if (picked != null) {
      setState(() {
        _temperatureTime = picked;
        _dirty = true;
      });
    }
  }

  Widget _temperatureField(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: TextField(
            key: const Key('temperature-field'),
            controller: _temperatureController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: Theme.of(context).textTheme.headlineMedium,
            decoration: const InputDecoration(
              suffixText: '°C',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            onChanged: (_) {
              _dirty = true;
              _temperatureTouched = true;
            },
          ),
        ),
        const SizedBox(width: 12),
        _timeButton(context),
        const Spacer(),
        IconButton.filledTonal(
          onPressed: () => _step(-_temperatureStep),
          icon: const Icon(Icons.remove),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () => _step(_temperatureStep),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  /// Shows the temperature's measurement time (from the sync or a prior edit) and
  /// opens a picker to set it by hand. Reads "Add time" until one is set.
  Widget _timeButton(BuildContext context) {
    final time = _temperatureTime;
    final label = time == null ? 'Add time' : time.format(context);
    return ActionChip(
      key: const Key('temperature-time'),
      avatar: const Icon(Icons.schedule, size: 18),
      label: Text(label),
      onPressed: _pickTime,
    );
  }

  Widget _chips<T>(
    String title,
    List<T> values,
    T? selected,
    String Function(T) label,
    ValueChanged<T> onSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(title),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                ChoiceChip(
                  label: Text(label(value)),
                  selected: value == selected,
                  onSelected: (_) {
                    _markDirty();
                    onSelected(value);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 0.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
