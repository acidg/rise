import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'chart_day.dart';

/// Width of one day column. The chart and the attribute table share this unit
/// and scroll together.
const double kColumnWidth = 44;

const double _tempMin = 36.0;
const double _tempMax = 37.3;

/// Height reserved above the plot for the per-day header (date, cycle day).
const double kChartHeaderHeight = 46;

/// Padding below the lowest plotted temperature.
const double kChartBottomPad = 8;

/// Major temperature grid lines in degrees Celsius, from 36.0 to 37.2 C every
/// 0.2 C, warmest first. Shared by the graph (which draws them) and the axis
/// gutter (which labels every one).
const List<double> kChartGridTemperatures = [
  37.2,
  37.0,
  36.8,
  36.6,
  36.4,
  36.2,
  36.0,
];

/// Y coordinate for [temperature] within a plot [plotHeight] pixels tall, using
/// the same scale as the graph. Lets the axis gutter align its labels with the
/// grid lines the painter draws.
double chartTempToY(double temperature, double plotHeight) =>
    _scaleTempToY(temperature, kChartHeaderHeight, plotHeight - kChartBottomPad);

double _scaleTempToY(double temperature, double top, double bottom) {
  final clamped = temperature.clamp(_tempMin, _tempMax);
  final fraction = (clamped - _tempMin) / (_tempMax - _tempMin);
  return bottom - fraction * (bottom - top);
}

const List<String> _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Draws the temperature curve with the fertile window, ovulation, coverline,
/// and the per-day header (date, cycle day, entry indicator). The other signs
/// are drawn by the attribute table below. Horizontal: one column per day,
/// oldest on the left.
class GraphPainter extends CustomPainter {
  final List<ChartDay> days;
  final ChartColors colors;
  final Color onSurface;
  final Color muted;
  final Color separator;

  GraphPainter({
    required this.days,
    required this.colors,
    required this.onSurface,
    required this.muted,
    required this.separator,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plotTop = kChartHeaderHeight;
    final plotBottom = size.height - kChartBottomPad;
    if (plotBottom <= plotTop) {
      return;
    }

    _paintZebra(canvas, size);
    _paintFertileBands(canvas, plotTop, plotBottom);
    _paintGridlines(canvas, size.width, plotTop, plotBottom);
    _paintCycleSeparators(canvas, plotTop, size.height);
    _paintReferenceLines(canvas, plotTop, plotBottom);
    _paintOvulation(canvas, plotTop, plotBottom);
    _paintTemperature(canvas, plotTop, plotBottom);
    _paintTodayTint(canvas, size);
    _paintHeaders(canvas);
  }

  double _centerX(int index) => index * kColumnWidth + kColumnWidth / 2;

  double _tempY(double temperature, double top, double bottom) =>
      _scaleTempToY(temperature, top, bottom);

  /// Faint horizontal grid lines at the major temperature values, drawn over the
  /// fertile band so the scale stays readable across the whole plot.
  void _paintGridlines(Canvas canvas, double width, double top, double bottom) {
    final paint = Paint()
      ..color = colors.axis
      ..strokeWidth = 1;
    for (final temperature in kChartGridTemperatures) {
      final y = _tempY(temperature, top, bottom);
      canvas.drawLine(Offset(0, y), Offset(width, y), paint);
    }
  }

  /// Vertical separator at the left edge of each cycle's first day, marking
  /// where a new cycle begins. It runs from the plot top through to the bottom
  /// and is continued across the attribute table below.
  void _paintCycleSeparators(Canvas canvas, double top, double bottom) {
    final paint = Paint()
      ..color = separator
      ..strokeWidth = 1;
    for (var i = 0; i < days.length; i++) {
      if (days[i].cycleDay != 1) {
        continue;
      }
      final x = i * kColumnWidth;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }
  }

  /// Subtle alternating column tint (zebra) to make columns easier to follow.
  void _paintZebra(Canvas canvas, Size size) {
    final paint = Paint()..color = colors.columnAlt;
    for (var i = 1; i < days.length; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(i * kColumnWidth, 0, kColumnWidth, size.height),
        paint,
      );
    }
  }

  void _paintFertileBands(Canvas canvas, double top, double bottom) {
    final solid = Paint()..color = colors.fertileFill;
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      if (!day.fertile) {
        continue;
      }
      final rect = Rect.fromLTRB(
        i * kColumnWidth,
        top,
        (i + 1) * kColumnWidth,
        bottom,
      );
      // Confirmed cycles show a solid window; an unconfirmed cycle's window is a
      // prediction, drawn hatched.
      if (day.confirmed) {
        canvas.drawRect(rect, solid);
      } else {
        _paintHatch(canvas, rect);
      }
    }
  }

  /// Diagonal hatch fill for a predicted (unconfirmed) fertile day.
  void _paintHatch(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = colors.hatchBg);
    final linePaint = Paint()
      ..color = colors.hatchLine
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(rect);
    const gap = 13.0;
    final height = rect.height;
    for (var x = rect.left - height; x < rect.right; x += gap) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + height, rect.top),
        linePaint,
      );
    }
    canvas.restore();
  }

  /// Draws, per shift band, the coverline (highest of the six lows) and the
  /// upper line for the lowest of the three higher measurements, with the
  /// difference between them labelled.
  void _paintReferenceLines(Canvas canvas, double top, double bottom) {
    final coverPaint = Paint()
      ..color = colors.coverline
      ..strokeWidth = 1.5;
    final lowPaint = Paint()
      ..color = colors.lowHigh
      ..strokeWidth = 1.5;
    var i = 0;
    while (i < days.length) {
      final cover = days[i].coverline;
      final low = days[i].lowestHigherTemperature;
      if (cover == null || low == null) {
        i++;
        continue;
      }
      var j = i;
      while (j + 1 < days.length &&
          days[j + 1].coverline == cover &&
          days[j + 1].lowestHigherTemperature == low) {
        j++;
      }
      final coverY = _tempY(cover, top, bottom);
      final lowY = _tempY(low, top, bottom);
      final left = i * kColumnWidth;
      final right = (j + 1) * kColumnWidth;
      _dashedLine(
        canvas,
        Offset(left, coverY),
        Offset(right, coverY),
        coverPaint,
      );
      _dashedLine(canvas, Offset(left, lowY), Offset(right, lowY), lowPaint);
      final diff = low - cover;
      _text(
        canvas,
        '+${diff.toStringAsFixed(2)}',
        left + 2,
        lowY - 14,
        colors.lowHigh,
        10,
        bold: true,
        leftAlign: true,
      );
      i = j + 1;
    }
  }

  void _paintOvulation(Canvas canvas, double top, double bottom) {
    final paint = Paint()
      ..color = colors.ovulation
      ..strokeWidth = 2;
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      if (!day.isOvulation) {
        continue;
      }
      final x = _centerX(i);
      // Confirmed (past) ovulation is a solid line; a predicted one is dashed.
      if (day.confirmed) {
        canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
      } else {
        _dashedLine(canvas, Offset(x, top), Offset(x, bottom), paint);
      }
    }
  }

  void _paintTemperature(Canvas canvas, double top, double bottom) {
    final linePaint = Paint()
      ..color = colors.temperature
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..color = Colors.white;

    // Collect the plotted points and draw the connecting line first, so the
    // dots sit cleanly on top of it rather than being clipped by later segments.
    final points = <Offset>[];
    final todayFlags = <bool>[];
    Offset? previous;
    for (var i = 0; i < days.length; i++) {
      final temperature = days[i].temperature;
      if (temperature == null) {
        previous = null;
        continue;
      }
      final point = Offset(_centerX(i), _tempY(temperature, top, bottom));
      if (previous != null) {
        canvas.drawLine(previous, point, linePaint);
      }
      points.add(point);
      todayFlags.add(days[i].isToday);
      previous = point;
    }

    // A white-filled dot with a coloured ring reads clearly against the line;
    // today's dot is drawn larger so it stands out.
    for (var i = 0; i < points.length; i++) {
      final isToday = todayFlags[i];
      final radius = isToday ? 6.5 : 5.0;
      final ringPaint = Paint()
        ..color = colors.temperature
        ..style = PaintingStyle.stroke
        ..strokeWidth = isToday ? 3.0 : 2.2;
      canvas.drawCircle(points[i], radius, fillPaint);
      canvas.drawCircle(points[i], radius, ringPaint);
    }
  }

  /// Translucent tint over today's column, so today stands out.
  void _paintTodayTint(Canvas canvas, Size size) {
    final index = days.indexWhere((d) => d.isToday);
    if (index < 0) {
      return;
    }
    canvas.drawRect(
      Rect.fromLTWH(index * kColumnWidth, 0, kColumnWidth, size.height),
      Paint()..color = colors.todayTint,
    );
  }

  void _paintHeaders(Canvas canvas) {
    const cycleDayY = 27.0;
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final centerX = _centerX(i);
      _text(
        canvas,
        '${day.date.day} ${_monthAbbr[day.date.month - 1]}',
        centerX,
        6,
        muted,
        9,
      );
      if (day.isToday) {
        // Today's cycle day sits in a filled pill so it stands out.
        final label = _layout(
          '${day.cycleDay}',
          13,
          bold: true,
          color: Colors.white,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(centerX, cycleDayY),
              width: label.width + 14,
              height: 20,
            ),
            const Radius.circular(10),
          ),
          Paint()..color = colors.temperature,
        );
        label.paint(
          canvas,
          Offset(centerX - label.width / 2, cycleDayY - label.height / 2),
        );
      } else {
        _text(
          canvas,
          '${day.cycleDay}',
          centerX,
          20,
          onSurface,
          13,
          bold: true,
        );
      }
      if (day.hasEntry) {
        canvas.drawCircle(
          Offset(centerX, 41),
          2,
          Paint()..color = colors.entryDot,
        );
      }
    }
  }

  TextPainter _layout(
    String value,
    double size, {
    bool bold = false,
    Color color = const Color(0xFF000000),
  }) {
    return TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 4.0;
    const gap = 3.0;
    final total = (to - from).distance;
    if (total == 0) {
      canvas.drawCircle(from, paint.strokeWidth / 2, paint);
      return;
    }
    final direction = (to - from) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final end = (drawn + dash).clamp(0.0, total);
      canvas.drawLine(from + direction * drawn, from + direction * end, paint);
      drawn += dash + gap;
    }
  }

  void _text(
    Canvas canvas,
    String value,
    double x,
    double top,
    Color color,
    double size, {
    bool bold = false,
    bool leftAlign = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = leftAlign ? x : x - painter.width / 2;
    painter.paint(canvas, Offset(dx, top));
  }

  @override
  bool shouldRepaint(GraphPainter oldDelegate) =>
      oldDelegate.days != days || oldDelegate.colors != colors;
}
