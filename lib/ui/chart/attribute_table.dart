import 'package:flutter/material.dart';

import '../../domain/models/day_entry.dart';
import '../../domain/models/signs.dart';
import '../../theme/app_theme.dart';
import 'chart_day.dart';
import 'chart_painter.dart';

/// Height of one attribute row in the table below the graph.
const double kAttrRowHeight = 30;

/// Row labels for the attribute table, shown in the frozen left gutter. The
/// order matches the rows drawn by [AttributeTablePainter].
const List<String> kAttrRowLabels = [
  'Temp',
  'Period',
  'Mucus',
  'Cervix',
  'Pain',
  'Mood',
  'Sex',
  'Libido',
];

/// Total height of the attribute table.
double attrTableHeight() => kAttrRowLabels.length * kAttrRowHeight;

const Map<Mood, Color> _moodColors = {
  Mood.great: Color(0xFF37C2A8),
  Mood.good: Color(0xFF7FD8C9),
  Mood.neutral: Color(0xFFB6BDC8),
  Mood.low: Color(0xFFF0A641),
  Mood.irritable: Color(0xFFE5544E),
};

const Map<Intercourse, ({Color color, String letter})> _sexStyle = {
  Intercourse.protectedSex: (color: Color(0xFF2FAE7A), letter: 'P'),
  Intercourse.unprotectedSex: (color: Color(0xFFE5544E), letter: 'U'),
  Intercourse.withdrawal: (color: Color(0xFFF0A641), letter: 'W'),
  Intercourse.self: (color: Color(0xFF8A76D8), letter: 'S'),
};

const Color _libidoColor = Color(0xFFC65AA6);

/// Draws the per-day attribute grid (one column per day, one row per sign),
/// with faint row separators. Shares [kColumnWidth] with the graph so the two
/// scroll together.
class AttributeTablePainter extends CustomPainter {
  final List<ChartDay> days;
  final ChartColors colors;
  final Color onSurface;
  final Color muted;
  final Color separator;

  AttributeTablePainter({
    required this.days,
    required this.colors,
    required this.onSurface,
    required this.muted,
    required this.separator,
  });

  double _centerX(int index) => index * kColumnWidth + kColumnWidth / 2;
  double _rowCenter(int row) => row * kAttrRowHeight + kAttrRowHeight / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final separatorPaint = Paint()
      ..color = separator
      ..strokeWidth = 1;
    // Row 0's line is the boundary between the graph and the table.
    for (var row = 0; row < kAttrRowLabels.length; row++) {
      final y = row * kAttrRowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), separatorPaint);
    }

    for (var i = 0; i < days.length; i++) {
      final entry = days[i].entry;
      final cx = _centerX(i);
      _temperature(canvas, entry, cx, _rowCenter(0));
      _period(canvas, entry.menstruation, cx, _rowCenter(1));
      _mucus(canvas, entry.mucus, cx, _rowCenter(2));
      _cervix(canvas, entry.cervix, cx, _rowCenter(3));
      _pain(canvas, entry.pain, cx, _rowCenter(4));
      _mood(canvas, entry.mood, cx, _rowCenter(5));
      _sex(canvas, entry.intercourse, cx, _rowCenter(6));
      _libido(canvas, entry.libido, cx, _rowCenter(7));
    }
  }

  void _faint(Canvas canvas, double cx, double cy) {
    canvas.drawCircle(
      Offset(cx, cy),
      1.6,
      Paint()..color = muted.withValues(alpha: 0.5),
    );
  }

  void _temperature(Canvas canvas, DayEntry entry, double cx, double cy) {
    final temperature = entry.temperature;
    if (temperature == null) {
      _faint(canvas, cx, cy);
      return;
    }
    _cellText(canvas, temperature.toStringAsFixed(2), cx, cy, onSurface, 9.5);
  }

  void _period(Canvas canvas, Menstruation menstruation, double cx, double cy) {
    final alpha = switch (menstruation) {
      Menstruation.heavy => 1.0,
      Menstruation.medium => 0.85,
      Menstruation.light => 0.6,
      Menstruation.spotting => 0.4,
      Menstruation.none => 0.0,
    };
    if (alpha == 0) {
      _faint(canvas, cx, cy);
      return;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 12, height: 16),
        const Radius.circular(3),
      ),
      Paint()..color = colors.period.withValues(alpha: alpha),
    );
  }

  void _mucus(Canvas canvas, CervicalMucus mucus, double cx, double cy) {
    final alpha = switch (mucus) {
      CervicalMucus.eggWhite => 1.0,
      CervicalMucus.watery => 0.75,
      CervicalMucus.creamy => 0.5,
      CervicalMucus.sticky => 0.35,
      CervicalMucus.dry || CervicalMucus.none => 0.0,
    };
    if (alpha == 0) {
      _faint(canvas, cx, cy);
      return;
    }
    canvas.drawCircle(
      Offset(cx, cy),
      6,
      Paint()..color = colors.mucus.withValues(alpha: alpha),
    );
  }

  void _cervix(Canvas canvas, Cervix? cervix, double cx, double cy) {
    if (cervix == null) {
      _faint(canvas, cx, cy);
      return;
    }
    final letter = switch (cervix) {
      Cervix.lowFirm => 'L',
      Cervix.medium => 'M',
      Cervix.highSoft => 'H',
    };
    _cellText(canvas, letter, cx, cy, onSurface, 12, bold: true);
  }

  int _painLevel(Pain pain) => switch (pain) {
    Pain.none => 0,
    Pain.mild => 1,
    Pain.moderate => 2,
    Pain.severe => 3,
  };

  void _pain(Canvas canvas, Pain pain, double cx, double cy) {
    final level = _painLevel(pain);
    if (level == 0) {
      _faint(canvas, cx, cy);
      return;
    }
    canvas.drawCircle(
      Offset(cx, cy),
      2 + level * 1.4,
      Paint()..color = const Color(0xFFF0A641),
    );
  }

  void _mood(Canvas canvas, Mood? mood, double cx, double cy) {
    if (mood == null) {
      _faint(canvas, cx, cy);
      return;
    }
    canvas.drawCircle(Offset(cx, cy), 6, Paint()..color = _moodColors[mood]!);
  }

  void _sex(Canvas canvas, Intercourse intercourse, double cx, double cy) {
    final style = _sexStyle[intercourse];
    if (style == null) {
      _faint(canvas, cx, cy);
      return;
    }
    canvas.drawCircle(Offset(cx, cy), 7, Paint()..color = style.color);
    _cellText(canvas, style.letter, cx, cy, Colors.white, 9, bold: true);
  }

  void _libido(Canvas canvas, Libido libido, double cx, double cy) {
    final level = switch (libido) {
      Libido.none => 0,
      Libido.low => 1,
      Libido.medium => 2,
      Libido.high => 3,
    };
    if (level == 0) {
      _faint(canvas, cx, cy);
      return;
    }
    canvas.drawCircle(
      Offset(cx, cy),
      2 + level * 1.4,
      Paint()..color = _libidoColor,
    );
  }

  void _cellText(
    Canvas canvas,
    String value,
    double cx,
    double cy,
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
    painter.paint(
      canvas,
      Offset(cx - painter.width / 2, cy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(AttributeTablePainter oldDelegate) =>
      oldDelegate.days != days || oldDelegate.colors != colors;
}
