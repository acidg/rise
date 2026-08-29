import 'package:flutter/material.dart';

/// Chart-specific colours that are not part of the Material [ColorScheme],
/// exposed as a theme extension so the chart flips with light/dark mode.
@immutable
class ChartColors extends ThemeExtension<ChartColors> {
  final Color temperature;
  final Color fertileFill;
  final Color ovulation;
  final Color coverline;
  final Color lowHigh;
  final Color period;
  final Color mucus;
  final Color axis;
  final Color entryDot;

  /// Translucent overlay tint for every other day column (zebra striping).
  final Color columnAlt;

  /// Background and line colours for the hatched (predicted) fertile window.
  final Color hatchBg;
  final Color hatchLine;

  const ChartColors({
    required this.temperature,
    required this.fertileFill,
    required this.ovulation,
    required this.coverline,
    required this.lowHigh,
    required this.period,
    required this.mucus,
    required this.axis,
    required this.entryDot,
    required this.columnAlt,
    required this.hatchBg,
    required this.hatchLine,
  });

  @override
  ChartColors copyWith({
    Color? temperature,
    Color? fertileFill,
    Color? ovulation,
    Color? coverline,
    Color? lowHigh,
    Color? period,
    Color? mucus,
    Color? axis,
    Color? entryDot,
    Color? columnAlt,
    Color? hatchBg,
    Color? hatchLine,
  }) {
    return ChartColors(
      temperature: temperature ?? this.temperature,
      fertileFill: fertileFill ?? this.fertileFill,
      ovulation: ovulation ?? this.ovulation,
      coverline: coverline ?? this.coverline,
      lowHigh: lowHigh ?? this.lowHigh,
      period: period ?? this.period,
      mucus: mucus ?? this.mucus,
      axis: axis ?? this.axis,
      entryDot: entryDot ?? this.entryDot,
      columnAlt: columnAlt ?? this.columnAlt,
      hatchBg: hatchBg ?? this.hatchBg,
      hatchLine: hatchLine ?? this.hatchLine,
    );
  }

  @override
  ChartColors lerp(ChartColors? other, double t) {
    if (other == null) {
      return this;
    }
    return ChartColors(
      temperature: Color.lerp(temperature, other.temperature, t)!,
      fertileFill: Color.lerp(fertileFill, other.fertileFill, t)!,
      ovulation: Color.lerp(ovulation, other.ovulation, t)!,
      coverline: Color.lerp(coverline, other.coverline, t)!,
      lowHigh: Color.lerp(lowHigh, other.lowHigh, t)!,
      period: Color.lerp(period, other.period, t)!,
      mucus: Color.lerp(mucus, other.mucus, t)!,
      axis: Color.lerp(axis, other.axis, t)!,
      entryDot: Color.lerp(entryDot, other.entryDot, t)!,
      columnAlt: Color.lerp(columnAlt, other.columnAlt, t)!,
      hatchBg: Color.lerp(hatchBg, other.hatchBg, t)!,
      hatchLine: Color.lerp(hatchLine, other.hatchLine, t)!,
    );
  }
}

const Color _brandPink = Color(0xFFE5679A);

const ChartColors _lightChart = ChartColors(
  temperature: Color(0xFF3A7AFE),
  fertileFill: Color(0xFFD7F2EA),
  ovulation: Color(0xFF7A5CFF),
  coverline: Color(0xFFC56B2C),
  lowHigh: Color(0xFF2F8F6B),
  period: _brandPink,
  mucus: Color(0xFF37C2A8),
  axis: Color(0xFFB6BDC8),
  entryDot: _brandPink,
  columnAlt: Color(0x08000000),
  hatchBg: Color(0xFFEEF9F5),
  hatchLine: Color(0xFF8FDCC9),
);

const ChartColors _darkChart = ChartColors(
  temperature: Color(0xFF5A90FF),
  fertileFill: Color(0xFF14342D),
  ovulation: Color(0xFF9C86FF),
  coverline: Color(0xFFE0955A),
  lowHigh: Color(0xFF59C79D),
  period: _brandPink,
  mucus: Color(0xFF4FD1B5),
  axis: Color(0xFF5A6675),
  entryDot: Color(0xFFFF8AB8),
  columnAlt: Color(0x0DFFFFFF),
  hatchBg: Color(0xFF12241F),
  hatchLine: Color(0xFF2F6B5E),
);

/// Light theme for Rise.
ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: _brandPink),
    extensions: const [_lightChart],
  );
}

/// Dark theme for Rise.
ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _brandPink,
      brightness: Brightness.dark,
    ),
    extensions: const [_darkChart],
  );
}
