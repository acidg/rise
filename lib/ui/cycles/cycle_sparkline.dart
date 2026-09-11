import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/fertility/cycle_analysis.dart';
import '../../theme/app_theme.dart';

/// Height of the thumbnail curve in the cycle list.
const double kSparklineHeight = 74;

/// Smallest temperature span a thumbnail is scaled over, so a cycle of nearly
/// flat readings does not turn its noise into a mountain range.
const double _minimumSpan = 0.5;

const double _verticalPadding = 8;

/// The cycle's temperature curve at thumbnail size, with its fertile window,
/// coverline and confirming line - the same picture as the main chart, small
/// enough to sit beside the explanation of how it was read.
///
/// Unlike the chart it scales to the cycle's own range rather than a fixed one,
/// because a thumbnail has to show the shape of the rise, not compare cycles.
class CycleSparkline extends StatelessWidget {
  final AnalyzedCycle analyzed;

  const CycleSparkline({super.key, required this.analyzed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: kSparklineHeight,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          analyzed: analyzed,
          colors: theme.extension<ChartColors>()!,
          muted: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final AnalyzedCycle analyzed;
  final ChartColors colors;
  final Color muted;

  _SparklinePainter({
    required this.analyzed,
    required this.colors,
    required this.muted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final days = analyzed.cycle.days;
    if (days.isEmpty || size.width <= 0) {
      return;
    }
    final temperatures = [for (final day in days) day.temperatureForAnalysis];
    final measured = temperatures.whereType<double>().toList();
    final window = analyzed.window;

    final range = _range(measured, window.coverline);
    double x(int index) => days.length == 1
        ? size.width / 2
        : size.width * index / (days.length - 1);
    double y(double temperature) {
      final fraction = (temperature - range.low) / (range.high - range.low);
      final usable = size.height - 2 * _verticalPadding;
      return size.height - _verticalPadding - fraction * usable;
    }

    _paintWindow(canvas, size, x);
    if (measured.isEmpty) {
      _paintEmptyNotice(canvas, size);
      return;
    }
    if (window.confirmed) {
      _paintReferenceLines(canvas, size, y);
    }
    _paintCurve(canvas, temperatures, x, y);
  }

  /// The fertile window as a soft band behind the curve, hatchless at this size:
  /// a thumbnail only has room for where the window was, not for how it was
  /// arrived at.
  void _paintWindow(Canvas canvas, Size size, double Function(int) x) {
    final window = analyzed.window;
    if (!analyzed.cycle.hasKnownStart) {
      return;
    }
    final last = window.open ? analyzed.cycle.length : window.lastFertileDay;
    if (last < window.firstFertileDay) {
      return;
    }
    final left = x(window.firstFertileDay - 1);
    final right = x(min(last, analyzed.cycle.length) - 1);
    canvas.drawRect(
      Rect.fromLTRB(left, 0, right, size.height),
      Paint()
        ..color = window.unevaluated ? colors.unknownBg : colors.fertileFill,
    );
    if (window.confirmed) {
      return;
    }
    // An open window has no closing edge; a dashed one would suggest a day.
    canvas.drawLine(
      Offset(right, 0),
      Offset(right, size.height),
      Paint()
        ..color = (window.unevaluated ? colors.unknownLine : colors.hatchLine)
        ..strokeWidth = 1,
    );
  }

  void _paintReferenceLines(
    Canvas canvas,
    Size size,
    double Function(double) y,
  ) {
    final window = analyzed.window;
    final coverY = y(window.coverline!);
    final confirmingY = y(window.confirmingTemperature!);
    canvas.drawLine(
      Offset(0, coverY),
      Offset(size.width, coverY),
      Paint()
        ..color = colors.coverline
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(0, confirmingY),
      Offset(size.width, confirmingY),
      Paint()
        ..color = colors.lowHigh
        ..strokeWidth = 1,
    );
  }

  void _paintCurve(
    Canvas canvas,
    List<double?> temperatures,
    double Function(int) x,
    double Function(double) y,
  ) {
    final linePaint = Paint()
      ..color = colors.temperature
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = colors.temperature;

    Offset? previous;
    for (var i = 0; i < temperatures.length; i++) {
      final temperature = temperatures[i];
      if (temperature == null) {
        previous = null;
        continue;
      }
      final point = Offset(x(i), y(temperature));
      if (previous != null) {
        canvas.drawLine(previous, point, linePaint);
      }
      canvas.drawCircle(point, 1.6, dotPaint);
      previous = point;
    }
  }

  void _paintEmptyNotice(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'No measurements',
        style: TextStyle(color: muted, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        (size.width - painter.width) / 2,
        (size.height - painter.height) / 2,
      ),
    );
  }

  /// Temperature range the thumbnail is scaled over: the measured values and the
  /// coverline, widened to [_minimumSpan] and centred when the readings sit
  /// closer together than that.
  ({double low, double high}) _range(List<double> measured, double? coverline) {
    if (measured.isEmpty) {
      return (low: 36.0, high: 37.0);
    }
    var low = measured.reduce(min);
    var high = measured.reduce(max);
    if (coverline != null) {
      low = min(low, coverline);
      high = max(high, coverline);
    }
    final span = high - low;
    if (span < _minimumSpan) {
      final centre = (high + low) / 2;
      low = centre - _minimumSpan / 2;
      high = centre + _minimumSpan / 2;
    }
    return (low: low, high: high);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.analyzed != analyzed || oldDelegate.colors != colors;
}
