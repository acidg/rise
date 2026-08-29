import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'chart_day.dart';

/// Width of one day column. The chart and the attribute table share this unit
/// and scroll together.
const double kColumnWidth = 44;

const double _tempMin = 36.0;
const double _tempMax = 37.3;
const double _headerHeight = 46;
const double _plotBottomPad = 8;

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

  GraphPainter({
    required this.days,
    required this.colors,
    required this.onSurface,
    required this.muted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plotTop = _headerHeight;
    final plotBottom = size.height - _plotBottomPad;
    if (plotBottom <= plotTop) {
      return;
    }

    _paintFertileBands(canvas, plotTop, plotBottom);
    _paintReferenceLines(canvas, plotTop, plotBottom);
    _paintOvulation(canvas, plotTop, plotBottom);
    _paintTemperature(canvas, plotTop, plotBottom);
    _paintHeaders(canvas);
  }

  double _centerX(int index) => index * kColumnWidth + kColumnWidth / 2;

  double _tempY(double temperature, double top, double bottom) {
    final clamped = temperature.clamp(_tempMin, _tempMax);
    final fraction = (clamped - _tempMin) / (_tempMax - _tempMin);
    return bottom - fraction * (bottom - top);
  }

  void _paintFertileBands(Canvas canvas, double top, double bottom) {
    final paint = Paint()..color = colors.fertileFill;
    for (var i = 0; i < days.length; i++) {
      if (!days[i].fertile) {
        continue;
      }
      canvas.drawRect(
        Rect.fromLTRB(i * kColumnWidth, top, (i + 1) * kColumnWidth, bottom),
        paint,
      );
    }
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
      final left = _centerX(i);
      final right = _centerX(j);
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
        (left + right) / 2,
        lowY - 14,
        colors.lowHigh,
        10,
        bold: true,
      );
      i = j + 1;
    }
  }

  void _paintOvulation(Canvas canvas, double top, double bottom) {
    final paint = Paint()
      ..color = colors.ovulation
      ..strokeWidth = 2;
    for (var i = 0; i < days.length; i++) {
      if (!days[i].isOvulation) {
        continue;
      }
      final x = _centerX(i);
      _dashedLine(canvas, Offset(x, top), Offset(x, bottom), paint);
    }
  }

  void _paintTemperature(Canvas canvas, double top, double bottom) {
    final linePaint = Paint()
      ..color = colors.temperature
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = colors.temperature;

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
      canvas.drawCircle(point, 3, dotPaint);
      previous = point;
    }
  }

  void _paintHeaders(Canvas canvas) {
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
      _text(canvas, '${day.cycleDay}', centerX, 20, onSurface, 13, bold: true);
      if (day.hasEntry) {
        canvas.drawCircle(
          Offset(centerX, 40),
          2,
          Paint()..color = colors.entryDot,
        );
      }
    }
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
    double centerX,
    double top,
    Color color,
    double size, {
    bool bold = false,
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
    painter.paint(canvas, Offset(centerX - painter.width / 2, top));
  }

  @override
  bool shouldRepaint(GraphPainter oldDelegate) =>
      oldDelegate.days != days || oldDelegate.colors != colors;
}
