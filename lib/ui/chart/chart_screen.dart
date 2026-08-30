import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../app_controller.dart';
import '../cycle_status.dart';
import '../detail/day_detail_sheet.dart';
import '../settings/settings_screen.dart';
import 'attribute_table.dart';
import 'chart_day.dart';
import 'chart_painter.dart';

const double _gutterWidth = 60;
const double _minGraphHeight = 160;

/// The primary screen: a horizontally scrolling chart of temperature with an
/// attribute table of the other daily signs below it, sharing one horizontal
/// scroll. A frozen left gutter labels the table rows. The view starts centred
/// on today, with the predicted days ahead to the right. Tapping a recorded day
/// opens its editable detail sheet.
class ChartScreen extends StatefulWidget {
  final AppController controller;

  const ChartScreen({super.key, required this.controller});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  final ScrollController _scroll = ScrollController();
  bool _centered = false;

  @override
  void initState() {
    super.initState();
    if (!widget.controller.isLoaded) {
      widget.controller.load();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openDetail(ChartDay day) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (_) =>
          DayDetailSheet(entry: day.entry, onSave: widget.controller.saveEntry),
    );
  }

  /// Centre the view on today once, after the first layout.
  void _centerOnToday(List<ChartDay> days) {
    if (_centered || days.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_centered || !_scroll.hasClients) {
        return;
      }
      var index = days.indexWhere((d) => d.isToday);
      if (index < 0) {
        index = days.length - 1;
      }
      final todayX = index * kColumnWidth + kColumnWidth / 2;
      final target = (todayX - _scroll.position.viewportDimension / 2).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      _scroll.jumpTo(target);
      _centered = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chartColors = theme.extension<ChartColors>()!;
    final onSurface = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => _title(context),
        ),
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
          _centerOnToday(days);
          final totalWidth = days.length * kColumnWidth;
          final tableHeight = attrTableHeight();

          // Keep the chart clear of the system bars (notably the bottom
          // navigation bar); the AppBar already covers the top inset.
          return SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final graphHeight = (constraints.maxHeight - tableHeight)
                    .clamp(_minGraphHeight, double.infinity)
                    .toDouble();

                // When the viewport is too short for the graph plus the table (a
                // short landscape window), the whole chart scrolls vertically
                // rather than overflowing; the gutter scrolls with it so its
                // labels stay aligned.
                final content = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _gutter(graphHeight, muted),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        child: GestureDetector(
                          key: const Key('chart'),
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (details) {
                            final index =
                                (details.localPosition.dx / kColumnWidth)
                                    .floor();
                            if (index >= 0 &&
                                index < days.length &&
                                !days[index].isFuture) {
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
                                    separator: theme.dividerColor,
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

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SizedBox(
                    height: graphHeight + tableHeight,
                    child: content,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Title bar summary: current cycle day with fertility phase and next event.
  /// Falls back to the app name before data has loaded.
  Widget _title(BuildContext context) {
    final controller = widget.controller;
    if (!controller.isLoaded || controller.days.isEmpty) {
      return const Text('Rise');
    }
    final theme = Theme.of(context);
    final status = controller.status;
    final subtitle = _subtitle(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Cycle day ${status.cycleDay ?? '?'}',
          style: theme.textTheme.titleMedium,
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  String? _subtitle(CycleStatus status) {
    if (!status.isKnown) {
      return 'No cycle detected';
    }
    final phase = status.phase == CyclePhase.fertile ? 'Fertile' : 'Infertile';
    final next = status.nextEvent;
    return next == null ? phase : '$phase · $next';
  }

  Widget _gutter(double graphHeight, Color muted) {
    final labelStyle = TextStyle(
      fontSize: 11,
      color: muted,
      fontWeight: FontWeight.w600,
    );
    final tempLabelStyle = TextStyle(fontSize: 10, color: muted);
    return SizedBox(
      width: _gutterWidth,
      child: Column(
        children: [
          SizedBox(
            height: graphHeight,
            child: Stack(
              children: [
                for (final temperature in kChartGridTemperatures)
                  Positioned(
                    right: 8,
                    top: chartTempToY(temperature, graphHeight) - 7,
                    child: Text(
                      temperature.toStringAsFixed(1),
                      style: tempLabelStyle,
                    ),
                  ),
              ],
            ),
          ),
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
