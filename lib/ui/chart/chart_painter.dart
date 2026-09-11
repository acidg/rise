import 'package:flutter/material.dart';

import '../../domain/fertility/temperature_shift.dart';
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
double chartTempToY(double temperature, double plotHeight) => _scaleTempToY(
  temperature,
  kChartHeaderHeight,
  plotHeight - kChartBottomPad,
);

double _scaleTempToY(double temperature, double top, double bottom) {
  final clamped = temperature.clamp(_tempMin, _tempMax);
  final fraction = (clamped - _tempMin) / (_tempMax - _tempMin);
  return bottom - fraction * (bottom - top);
}

const List<String> _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Colour of the year boundary line and its label border: derived from the text
/// colour so it reads as structure in both themes, and stronger than a cycle
/// separator without competing with the curve.
Color yearBoundaryColor(Color onSurface) => onSurface.withValues(alpha: 0.45);

/// Columns kept on either side of the viewport, so a column scrolled halfway in
/// is already drawn and the temperature line reaches its off-screen neighbour.
const int _columnMargin = 2;

/// The columns of [dayCount] that a viewport [viewportWidth] wide shows at
/// [scrollOffset], widened by a small margin. Both painters record only these,
/// because a multi-year history is tens of thousands of pixels wide: recording
/// every column costs a text layout per day per repaint and a picture far larger
/// than the screen.
/// Whether a column starting on [date] opens a calendar year the column before
/// it, on [previous], did not belong to. The first column of the chart is not a
/// change of year, so it is never a boundary.
bool startsYear(DateTime date, DateTime? previous) =>
    previous != null && date.year != previous.year;

/// The chart's horizontal scroll offset, zero until the view is attached.
double scrollOffset(ScrollController scroll) =>
    scroll.hasClients ? scroll.offset : 0;

({int first, int last}) visibleColumns(
  int dayCount,
  double scrollOffset,
  double viewportWidth,
) {
  if (dayCount == 0) {
    return (first: 0, last: -1);
  }
  final first = (scrollOffset / kColumnWidth).floor() - _columnMargin;
  final last =
      ((scrollOffset + viewportWidth) / kColumnWidth).ceil() + _columnMargin;
  return (
    first: first.clamp(0, dayCount - 1),
    last: last.clamp(0, dayCount - 1),
  );
}

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

  /// The chart's horizontal scroll, both the repaint trigger and the source of
  /// the visible range: only the columns on screen are drawn.
  final ScrollController scroll;

  /// Width of the chart's viewport, from the enclosing layout rather than the
  /// canvas, which spans the whole history.
  final double viewportWidth;

  /// Background behind the year label, so it stays readable over a fertile band.
  final Color surface;

  /// Columns currently on screen, set at the start of each paint.
  int _first = 0;
  int _last = -1;

  GraphPainter({
    required this.days,
    required this.colors,
    required this.onSurface,
    required this.muted,
    required this.separator,
    required this.scroll,
    required this.viewportWidth,
    required this.surface,
  }) : super(repaint: scroll);

  @override
  void paint(Canvas canvas, Size size) {
    final plotTop = kChartHeaderHeight;
    final plotBottom = size.height - kChartBottomPad;
    if (plotBottom <= plotTop) {
      return;
    }
    final range = visibleColumns(
      days.length,
      scrollOffset(scroll),
      viewportWidth,
    );
    _first = range.first;
    _last = range.last;

    _paintZebra(canvas, size);
    _paintFertileBands(canvas, plotTop, plotBottom);
    _paintGridlines(canvas, size.width, plotTop, plotBottom);
    _paintCycleSeparators(canvas, plotTop, size.height);
    _paintYearBoundaries(canvas, plotTop, size.height);
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
    final left = _first * kColumnWidth;
    final right = (_last + 1) * kColumnWidth;
    for (final temperature in kChartGridTemperatures) {
      final y = _tempY(temperature, top, bottom);
      canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    }
  }

  /// Vertical separator at the left edge of each cycle's first day, marking
  /// where a new cycle begins. It runs from the plot top through to the bottom
  /// and is continued across the attribute table below.
  void _paintCycleSeparators(Canvas canvas, double top, double bottom) {
    final paint = Paint()
      ..color = separator
      ..strokeWidth = 1;
    for (var i = _first; i <= _last; i++) {
      if (days[i].cycleDay != 1) {
        continue;
      }
      final x = i * kColumnWidth;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }
  }

  /// Marks where the record crosses into a new calendar year: a line stronger
  /// than the cycle separators, labelled with the year it opens. Only the
  /// boundary is marked, so the label appears once per year rather than on every
  /// column, and the day headers stay uncluttered.
  void _paintYearBoundaries(Canvas canvas, double top, double bottom) {
    final linePaint = Paint()
      ..color = yearBoundaryColor(onSurface)
      ..strokeWidth = 1.5;
    for (var i = _first; i <= _last; i++) {
      if (!startsYear(days[i].date, i > 0 ? days[i - 1].date : null)) {
        continue;
      }
      final x = i * kColumnWidth;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), linePaint);
      _yearLabel(canvas, days[i].date.year, x, top);
    }
  }

  /// The year in a small filled chip beside its boundary line.
  void _yearLabel(Canvas canvas, int year, double x, double top) {
    final label = _layout('$year', 10, bold: true, color: onSurface);
    final rect = Rect.fromLTWH(
      x + 3,
      top + 4,
      label.width + 10,
      label.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = surface,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = yearBoundaryColor(onSurface)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    label.paint(canvas, Offset(rect.left + 5, rect.top + 2));
  }

  /// Subtle alternating column tint (zebra) to make columns easier to follow.
  void _paintZebra(Canvas canvas, Size size) {
    final paint = Paint()..color = colors.columnAlt;
    for (var i = _first.isOdd ? _first : _first + 1; i <= _last; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(i * kColumnWidth, 0, kColumnWidth, size.height),
        paint,
      );
    }
  }

  void _paintFertileBands(Canvas canvas, double top, double bottom) {
    final solid = Paint()..color = colors.fertileFill;
    for (var i = _first; i <= _last; i++) {
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
      // prediction, drawn hatched. A window that rests on no evaluation is
      // hatched in neutral grey instead, so it does not read as a fertile phase
      // the data actually showed.
      if (day.confirmed) {
        canvas.drawRect(rect, solid);
      } else if (day.unevaluated) {
        _paintHatch(canvas, rect, colors.unknownBg, colors.unknownLine);
      } else {
        _paintHatch(canvas, rect, colors.hatchBg, colors.hatchLine);
      }
    }
  }

  /// Diagonal hatch fill for a predicted (unconfirmed) fertile day.
  void _paintHatch(Canvas canvas, Rect rect, Color background, Color line) {
    canvas.drawRect(rect, Paint()..color = background);
    final linePaint = Paint()
      ..color = line
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
  /// upper line for the measurement that completed the evaluation, with the
  /// difference between them labelled. Reaching [kShiftMinimumRise] is what the
  /// rule asks of the third measurement; a band confirmed below that mark was
  /// closed by the fourth-day exception instead, and its line is toned down to
  /// show it.
  void _paintReferenceLines(Canvas canvas, double top, double bottom) {
    final coverPaint = Paint()
      ..color = colors.coverline
      ..strokeWidth = 1.5;
    var i = _first;
    while (i <= _last) {
      final cover = days[i].coverline;
      final confirming = days[i].confirmingTemperature;
      if (cover == null || confirming == null) {
        i++;
        continue;
      }
      // A band may start off screen; walk back to its real start so the line and
      // its label do not shift as the chart scrolls.
      while (i > 0 &&
          days[i - 1].coverline == cover &&
          days[i - 1].confirmingTemperature == confirming) {
        i--;
      }
      var j = i;
      while (j + 1 < days.length &&
          days[j + 1].coverline == cover &&
          days[j + 1].confirmingTemperature == confirming) {
        j++;
      }
      // Compared in hundredths, the precision temperatures are recorded at, so a
      // rise of exactly the minimum is not lost to floating-point error.
      final hundredths = ((confirming - cover) * 100).round();
      final reachedMinimumRise =
          hundredths >= (kShiftMinimumRise * 100).round();
      final confirmingPaint = Paint()
        ..color = reachedMinimumRise
            ? colors.lowHigh
            : colors.lowHigh.withValues(alpha: 0.55)
        ..strokeWidth = 1.5;
      final coverY = _tempY(cover, top, bottom);
      final confirmingY = _tempY(confirming, top, bottom);
      final left = i * kColumnWidth;
      final right = (j + 1) * kColumnWidth;
      _dashedLine(
        canvas,
        Offset(left, coverY),
        Offset(right, coverY),
        coverPaint,
      );
      _dashedLine(
        canvas,
        Offset(left, confirmingY),
        Offset(right, confirmingY),
        confirmingPaint,
      );
      _text(
        canvas,
        '+${(hundredths / 100).toStringAsFixed(2)}',
        left + 2,
        confirmingY - 14,
        confirmingPaint.color,
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
    for (var i = _first; i <= _last; i++) {
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
    final excluded = <Offset>[];
    Offset? previous;
    for (var i = _first; i <= _last; i++) {
      final temperature = days[i].temperature;
      if (temperature == null) {
        previous = null;
        continue;
      }
      final point = Offset(_centerX(i), _tempY(temperature, top, bottom));
      // An excluded measurement is a gap to the rules, so the curve breaks
      // around it exactly as it does on an unmeasured day. The dot stays, drawn
      // muted, because the value was still taken.
      if (days[i].temperatureExcluded) {
        excluded.add(point);
        previous = null;
        continue;
      }
      if (previous != null) {
        canvas.drawLine(previous, point, linePaint);
      }
      points.add(point);
      todayFlags.add(days[i].isToday);
      previous = point;
    }

    final excludedRing = Paint()
      ..color = muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final point in excluded) {
      canvas.drawCircle(point, 4.0, fillPaint);
      canvas.drawCircle(point, 4.0, excludedRing);
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
    final index = _indexOfToday();
    if (index < 0) {
      return;
    }
    canvas.drawRect(
      Rect.fromLTWH(index * kColumnWidth, 0, kColumnWidth, size.height),
      Paint()..color = colors.todayTint,
    );
  }

  /// Index of today's column within the visible range, or -1 when it is off
  /// screen.
  int _indexOfToday() {
    for (var i = _first; i <= _last; i++) {
      if (days[i].isToday) {
        return i;
      }
    }
    return -1;
  }

  void _paintHeaders(Canvas canvas) {
    const cycleDayY = 27.0;
    for (var i = _first; i <= _last; i++) {
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
      final cycleDayLabel = day.cycleDay?.toString() ?? '?';
      if (day.isToday) {
        // Today's cycle day sits in a filled pill so it stands out.
        final label = _layout(
          cycleDayLabel,
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
        _text(canvas, cycleDayLabel, centerX, 20, onSurface, 13, bold: true);
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
      oldDelegate.days != days ||
      oldDelegate.colors != colors ||
      oldDelegate.scroll != scroll ||
      oldDelegate.viewportWidth != viewportWidth ||
      oldDelegate.surface != surface;
}
