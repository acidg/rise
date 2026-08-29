import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../app_controller.dart';
import '../detail/day_detail_sheet.dart';
import '../settings/settings_screen.dart';
import 'chart_day.dart';
import 'chart_painter.dart';

/// The primary screen: a horizontally scrolling chart of temperature and the
/// other daily signs. Tapping a day opens its editable detail sheet.
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
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true, // start at the most recent day
                child: GestureDetector(
                  key: const Key('chart'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final index = (details.localPosition.dx / kColumnWidth)
                        .floor();
                    if (index >= 0 && index < days.length) {
                      _openDetail(days[index]);
                    }
                  },
                  child: CustomPaint(
                    size: Size(
                      days.length * kColumnWidth,
                      constraints.maxHeight,
                    ),
                    painter: ChartPainter(
                      days: days,
                      colors: chartColors,
                      onSurface: theme.colorScheme.onSurface,
                      muted: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
