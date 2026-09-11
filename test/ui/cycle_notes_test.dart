import 'package:flutter_test/flutter_test.dart';
import 'package:rise/domain/fertility/cycle_evaluation.dart';
import 'package:rise/domain/fertility/symptothermal_analyzer.dart';
import 'package:rise/domain/models/cycle.dart';
import 'package:rise/domain/models/signs.dart';
import 'package:rise/ui/cycles/cycle_notes.dart';

import '../support/cycle_builder.dart';

void main() {
  const analyzer = SensiplanAnalyzer();

  List<String> describe(Cycle cycle) {
    final window = analyzer.analyze([cycle]).single;
    return describeCycle(
      evaluateCycle(cycle, window),
    ).map((n) => n.text).toList();
  }

  String only(List<String> notes, String fragment) =>
      notes.singleWhere((note) => note.contains(fragment));

  test('a confirmed cycle names the coverline, the rise and the window', () {
    final notes = describe(
      buildCycle(
        temperatures: biphasic(lowDays: 8),
        mucus: {5: CervicalMucus.eggWhite},
      ),
    );

    expect(only(notes, 'Rise confirmed'), contains('+0.35 C'));
    expect(only(notes, 'Coverline'), contains('36.40 C'));
    expect(only(notes, 'Mucus peak'), contains('three more days'));
  });

  test('a cycle with one measurement before the rise reads as singular', () {
    final notes = describe(
      buildCycle(
        temperatures: [
          null, null, null, null, null, null, //
          36.40, 36.90, 36.95, 36.92, 36.98,
        ],
      ),
    );

    expect(only(notes, 'The curve rises'), contains('only one measurement'));
  });

  test('a cycle with nothing logged says what to do about it', () {
    final notes = describe(buildCycle(temperatures: List.filled(26, null)));

    expect(
      only(notes, 'No temperature evaluation'),
      contains('nothing was measured'),
    );
    expect(only(notes, 'Measure on waking'), isNotEmpty);
    expect(only(notes, 'No mucus logged'), isNotEmpty);
  });

  test('a cycle that ends before its window opens says so', () {
    // Bleeding that starts again after four days leaves a run shorter than the
    // days the five-day rule frees, so the window opens past the last day.
    final previous = buildCycle(temperatures: biphasic(lowDays: 8));
    final short = buildCycle(temperatures: List.filled(4, null));
    final windows = analyzer.analyze([previous, short]);
    final notes = describeCycle(
      evaluateCycle(short, windows.last),
    ).map((n) => n.text).toList();

    expect(only(notes, 'Window would have opened'), contains('day 6'));
    expect(only(notes, 'The cycle ended'), contains('no fertile day'));
    expect(notes.where((n) => n.contains('never closed')), isEmpty);
  });

  test('an unevaluable window explains that no calendar rule applied', () {
    final previous = buildCycle(temperatures: List.filled(26, null));
    final current = buildCycle(
      temperatures: List.filled(12, null),
      isCurrent: true,
    );
    final windows = analyzer.analyze([previous, current]);
    final notes = describeCycle(
      evaluateCycle(current, windows.last),
    ).map((n) => n.text).toList();

    expect(only(notes, 'Window opens'), contains('neither calendar rule'));
  });
}
