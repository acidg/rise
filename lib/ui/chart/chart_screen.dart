import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../app_controller.dart';
import '../detail/day_detail_sheet.dart';
import '../settings/settings_screen.dart';
import 'attribute_table.dart';
import 'chart_day.dart';
import 'chart_painter.dart';

const double _gutterWidth = 60;
const double _minGraphHeight = 160;

/// The primary screen: a horizontally scrolling chart of temperature with an
/// attribute table of the other daily signs below it, sharing one horizontal
/// scroll. A frozen left gutter labels the table rows. Tapping a day opens its
/// editable detail sheet.
class ChartScreen extends StatefulWidget {
  final AppController controller;

  const ChartScreen({super.key, required this.controller});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.controller.isLoaded) {
      widget.controller.load();
    }
  }

  void _openDetail(ChartDay day) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          DayDetailSheet(entry: day.entry, onSave: widget.controller.saveEntry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chartColors = theme.extension<ChartColors>()!;
    final onSurface = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rise'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(controller: widget.controller),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          if (!widget.controller.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final days = widget.controller.days;
          if (days.isEmpty) {
            return const Center(child: Text('No measurements yet'));
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = days.length * kColumnWidth;
              final tableHeight = attrTableHeight();
              final graphHeight = (constraints.maxHeight - tableHeight)
                  .clamp(_minGraphHeight, double.infinity)
                  .toDouble();

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _gutter(graphHeight, muted),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true, // start at the most recent day
                      child: GestureDetector(
                        key: const Key('chart'),
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          final index =
                              (details.localPosition.dx / kColumnWidth).floor();
                          if (index >= 0 && index < days.length) {
                            _openDetail(days[index]);
                          }
                        },
                        child: SizedBox(
                          width: totalWidth,
                          height: graphHeight + tableHeight,
                          child: Column(
                            children: [
                              CustomPaint(
                                size: Size(totalWidth, graphHeight),
                                painter: GraphPainter(
                                  days: days,
                                  colors: chartColors,
                                  onSurface: onSurface,
                                  muted: muted,
                                ),
                              ),
                              CustomPaint(
                                size: Size(totalWidth, tableHeight),
                                painter: AttributeTablePainter(
                                  days: days,
                                  colors: chartColors,
                                  onSurface: onSurface,
                                  muted: muted,
                                  separator: theme.dividerColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _gutter(double graphHeight, Color muted) {
    final labelStyle = TextStyle(
      fontSize: 11,
      color: muted,
      fontWeight: FontWeight.w600,
    );
    return SizedBox(
      width: _gutterWidth,
      child: Column(
        children: [
          SizedBox(height: graphHeight),
          for (final label in kAttrRowLabels)
            SizedBox(
              height: kAttrRowHeight,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(label, style: labelStyle),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
