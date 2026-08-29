import 'dart:math';

import '../domain/models/day_entry.dart';
import '../domain/models/signs.dart';

/// Luteal phase length used to place ovulation within a generated cycle.
const int _lutealLength = 14;

/// Number of days recorded in the still-open current cycle.
const int _currentRecordedDays = 12;

/// Generates several cycles of realistic sample data ending on [today].
///
/// Used by the demo repository and for developing the chart without a physical
/// device. Deterministic (seeded) so the chart looks the same across runs. The
/// current cycle is partial, sitting a few days before ovulation, so it renders
/// as an open, unconfirmed window.
List<DayEntry> generateSampleEntries({int pastCycles = 3, DateTime? today}) {
  final end = _dateOnly(today ?? DateTime(2026, 8, 29));
  final random = Random(20260829);

  final pastLengths = [
    for (var i = 0; i < pastCycles; i++) 27 + random.nextInt(5),
  ];
  final totalDays =
      pastLengths.fold<int>(0, (sum, l) => sum + l) + _currentRecordedDays;
  final start = end.subtract(Duration(days: totalDays - 1));

  final entries = <DayEntry>[];
  var offset = 0;
  for (final length in pastLengths) {
    for (var day = 1; day <= length; day++) {
      entries.add(
        _dayFor(start.add(Duration(days: offset)), day, length, random),
      );
      offset++;
    }
  }
  // Current cycle: a nominal 28-day pattern, but only the first days recorded.
  for (var day = 1; day <= _currentRecordedDays; day++) {
    entries.add(_dayFor(start.add(Duration(days: offset)), day, 28, random));
    offset++;
  }
  return entries;
}

DayEntry _dayFor(DateTime date, int day, int cycleLength, Random random) {
  final ovulationDay = cycleLength - _lutealLength;
  return DayEntry(
    date: date,
    temperature: _temperature(day, ovulationDay, random),
    menstruation: _menstruation(day),
    mucus: _mucus(day, ovulationDay),
    cervix: _cervix(day, ovulationDay),
    pain: _pain(day, ovulationDay),
    mood: _mood(day, ovulationDay),
    libido: _libido(day, ovulationDay),
    intercourse: _intercourse(day, ovulationDay, random),
    notes: _notes(day, ovulationDay),
  );
}

double _temperature(int day, int ovulationDay, Random random) {
  double base;
  if (day == ovulationDay - 1) {
    base = 36.30; // pre-ovulation dip
  } else if (day == ovulationDay) {
    base = 36.42;
  } else if (day > ovulationDay) {
    base = 36.78 + min((day - ovulationDay) * 0.01, 0.14);
  } else {
    base = 36.45;
  }
  final jitter = (random.nextDouble() * 2 - 1) * 0.05;
  return double.parse((base + jitter).toStringAsFixed(2));
}

Menstruation _menstruation(int day) {
  return switch (day) {
    1 => Menstruation.medium,
    2 => Menstruation.heavy,
    3 => Menstruation.medium,
    4 => Menstruation.light,
    5 => Menstruation.spotting,
    _ => Menstruation.none,
  };
}

CervicalMucus _mucus(int day, int ovulationDay) {
  if (day < 6) {
    return day <= 3 ? CervicalMucus.none : CervicalMucus.dry;
  }
  if (day < ovulationDay - 3) {
    return CervicalMucus.sticky;
  }
  if (day < ovulationDay - 1) {
    return CervicalMucus.creamy;
  }
  if (day <= ovulationDay) {
    return CervicalMucus.eggWhite;
  }
  if (day == ovulationDay + 1) {
    return CervicalMucus.watery;
  }
  return CervicalMucus.dry;
}

Cervix _cervix(int day, int ovulationDay) {
  if (day >= ovulationDay - 3 && day <= ovulationDay) {
    return Cervix.highSoft;
  }
  return day <= 6 ? Cervix.medium : Cervix.lowFirm;
}

Pain _pain(int day, int ovulationDay) {
  if (day <= 2) {
    return Pain.moderate;
  }
  if (day == 3) {
    return Pain.mild;
  }
  if (day == ovulationDay) {
    return Pain.mild; // mittelschmerz
  }
  return Pain.none;
}

Mood _mood(int day, int ovulationDay) {
  if (day <= 2) {
    return Mood.low;
  }
  if (day >= ovulationDay - 1 && day <= ovulationDay + 1) {
    return Mood.great;
  }
  return Mood.good;
}

Libido _libido(int day, int ovulationDay) {
  if (day <= 5) {
    return Libido.none;
  }
  if (day >= ovulationDay - 4 && day <= ovulationDay + 1) {
    return Libido.high;
  }
  if (day >= ovulationDay - 7) {
    return Libido.medium;
  }
  return Libido.low;
}

Intercourse _intercourse(int day, int ovulationDay, Random random) {
  final roll = random.nextDouble();
  if (day >= ovulationDay - 5 && day <= ovulationDay + 1) {
    if (roll < 0.5) {
      return roll < 0.3 ? Intercourse.unprotectedSex : Intercourse.protectedSex;
    }
    return Intercourse.none;
  }
  if (roll < 0.12) {
    return Intercourse.protectedSex;
  }
  return Intercourse.none;
}

String _notes(int day, int ovulationDay) {
  if (day == 1) {
    return 'Period started.';
  }
  if (day == ovulationDay) {
    return 'Ovulation twinge, positive OPK.';
  }
  return '';
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
