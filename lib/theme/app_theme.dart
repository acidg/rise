import 'package:flutter/material.dart';

/// Chart-specific colours that are not part of the Material [ColorScheme],
/// exposed as a theme extension so the chart flips with light/dark mode.
@immutable
class ChartColors extends ThemeExtension<ChartColors> {
  final Color temperature;
  final Color fertileFill;
  final Color ovulation;
  final Color coverline;
  final Color period;
  final Color mucus;
  final Color axis;
  final Color entryDot;

  const ChartColors({
    required this.temperature,
    required this.fertileFill,
    required this.ovulation,
    required this.coverline,
    required this.period,
    required this.mucus,
    required this.axis,
    required this.entryDot,
  });

  @override
  ChartColors copyWith({
    Color? temperature,
    Color? fertileFill,
    Color? ovulation,
    Color? coverline,
    Color? period,
    Color? mucus,
    Color? axis,
    Color? entryDot,
  }) {
    return ChartColors(
      temperature: temperature ?? this.temperature,
      fertileFill: fertileFill ?? this.fertileFill,
      ovulation: ovulation ?? this.ovulation,
      coverline: coverline ?? this.coverline,
      period: period ?? this.period,
      mucus: mucus ?? this.mucus,
      axis: axis ?? this.axis,
      entryDot: entryDot ?? this.entryDot,
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
      period: Color.lerp(period, other.period, t)!,
      mucus: Color.lerp(mucus, other.mucus, t)!,
      axis: Color.lerp(axis, other.axis, t)!,
      entryDot: Color.lerp(entryDot, other.entryDot, t)!,
    );
  }
}

const Color _brandPink = Color(0xFFE5679A);

const ChartColors _lightChart = ChartColors(
  temperature: Color(0xFF3A7AFE),
  fertileFill: Color(0xFFD7F2EA),
  ovulation: Color(0xFF7A5CFF),
  coverline: Color(0xFFC56B2C),
  period: _brandPink,
  mucus: Color(0xFF37C2A8),
  axis: Color(0xFFB6BDC8),
  entryDot: _brandPink,
);

const ChartColors _darkChart = ChartColors(
  temperature: Color(0xFF5A90FF),
  fertileFill: Color(0xFF14342D),
  ovulation: Color(0xFF9C86FF),
  coverline: Color(0xFFE0955A),
  period: _brandPink,
  mucus: Color(0xFF4FD1B5),
  axis: Color(0xFF5A6675),
  entryDot: Color(0xFFFF8AB8),
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
