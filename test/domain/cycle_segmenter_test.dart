import 'package:flutter_test/flutter_test.dart';
import 'package:rise/domain/fertility/cycle_segmenter.dart';
import 'package:rise/domain/models/day_entry.dart';
import 'package:rise/domain/models/signs.dart';

void main() {
  const segmenter = MenstruationCycleSegmenter();
  final base = DateTime(2026, 1, 1);

  DayEntry day(int offset, Menstruation menstruation) {
    return DayEntry(
      date: base.add(Duration(days: offset)),
      menstruation: menstruation,
    );
  }

  test('starts a new cycle on each menstruation onset', () {
    final days = <DayEntry>[
      day(0, Menstruation.medium),
      day(1, Menstruation.heavy),
      day(2, Menstruation.light),
      for (var i = 3; i < 14; i++) day(i, Menstruation.none),
      day(14, Menstruation.medium), // onset of the next cycle
      day(15, Menstruation.light),
      for (var i = 16; i < 20; i++) day(i, Menstruation.none),
    ];

    final cycles = segmenter.segment(days);

    expect(cycles.length, 2);
    expect(cycles[0].length, 14);
    expect(cycles[1].length, 6);
    expect(cycles[1].isCurrent, isTrue);
  });

  test('data starting mid-cycle keeps the leading run as unknown-start', () {
    final days = <DayEntry>[
      // Recording began before any bleeding was logged.
      for (var i = 0; i < 6; i++) day(i, Menstruation.none),
      day(6, Menstruation.medium), // first observed onset
      for (var i = 7; i < 12; i++) day(i, Menstruation.none),
    ];

    final cycles = segmenter.segment(days);

    expect(cycles.length, 2);
    expect(cycles[0].hasKnownStart, isFalse);
    expect(cycles[0].length, 6);
    expect(cycles[1].hasKnownStart, isTrue);
    expect(cycles[1].isCurrent, isTrue);
    expect(cycles[1].length, 6);
  });

  test('with no bleeding at all the whole record is one unknown-start cycle', () {
    final days = [for (var i = 0; i < 8; i++) day(i, Menstruation.none)];

    final cycles = segmenter.segment(days);

    expect(cycles.length, 1);
    expect(cycles.single.hasKnownStart, isFalse);
    expect(cycles.single.isCurrent, isTrue);
  });

  test('mid-cycle spotting does not start a new cycle', () {
    final days = <DayEntry>[
      day(0, Menstruation.medium),
      for (var i = 1; i < 10; i++) day(i, Menstruation.none),
      day(10, Menstruation.spotting), // ovulation spotting, not a real period
      for (var i = 11; i < 20; i++) day(i, Menstruation.none),
    ];

    final cycles = segmenter.segment(days);

    expect(cycles.length, 1);
  });
}
