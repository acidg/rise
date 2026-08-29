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
  late double _temperature;
  late final TextEditingController _temperatureController;
  late Menstruation _menstruation;
  late CervicalMucus _mucus;
  Cervix? _cervix;
  late Pain _pain;
  Mood? _mood;
  late Libido _libido;
  late Intercourse _intercourse;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _temperature = entry.temperature ?? _defaultTemperature;
    _temperatureController = TextEditingController(
      text: _temperature.toStringAsFixed(2),
    );
    _menstruation = entry.menstruation;
    _mucus = entry.mucus;
    _cervix = entry.cervix;
    _pain = entry.pain;
    _mood = entry.mood;
    _libido = entry.libido;
    _intercourse = entry.intercourse;
    _notes = TextEditingController(text: entry.notes);
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// The temperature currently in the text field, falling back to the last
  /// valid value when the field holds an incomplete or unparseable entry.
  double get _currentTemperature =>
      double.tryParse(_temperatureController.text.replaceAll(',', '.')) ??
      _temperature;

  /// Adjust the temperature by [delta] from the value currently shown and
  /// rewrite the field, keeping it to two decimals.
  void _step(double delta) {
    final next = double.parse((_currentTemperature + delta).toStringAsFixed(2));
    setState(() {
      _temperature = next;
      _temperatureController.text = next.toStringAsFixed(2);
    });
  }

  void _save() {
    widget.onSave(
      widget.entry.copyWith(
        temperature: _currentTemperature,
        menstruation: _menstruation,
        mucus: _mucus,
        cervix: _cervix,
        pain: _pain,
        mood: _mood,
        libido: _libido,
        intercourse: _intercourse,
        notes: _notes.text,
      ),
    );
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
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (value) {
              final parsed = double.tryParse(value.replaceAll(',', '.'));
              if (parsed != null) {
                _temperature = parsed;
              }
            },
          ),
        ),
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
                  onSelected: (_) => onSelected(value),
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
