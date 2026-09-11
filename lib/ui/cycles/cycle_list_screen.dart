import 'package:flutter/material.dart';

import '../../domain/fertility/cycle_analysis.dart';
import '../../domain/fertility/cycle_evaluation.dart';
import '../app_controller.dart';
import '../date_format.dart';
import 'cycle_notes.dart';
import 'cycle_sparkline.dart';

/// Lists every cycle in the record with its curve and an account of how the
/// rules read it: which one opened the fertile window, how far the temperature
/// evaluation got, and what the record would need for the rules to say more.
///
/// The point is not the verdict but the reasoning behind it, so a gap in the
/// data becomes something to act on rather than a silent "no evaluation".
///
/// Tapping a cycle closes the page and returns its first day, which the chart
/// scrolls to.
class CycleListScreen extends StatelessWidget {
  final AppController controller;

  const CycleListScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cycles')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final cycles = controller.cycles;
          if (cycles.isEmpty) {
            return const Center(child: Text('No cycles recorded yet'));
          }
          // Newest first: the cycle you are in is the one you can still act on.
          final ordered = cycles.reversed.toList();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: ordered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _CycleCard(
              analyzed: ordered[index],
              number: cycles.length - index,
            ),
          );
        },
      ),
    );
  }
}

class _CycleCard extends StatelessWidget {
  final AnalyzedCycle analyzed;

  /// Position in the record, oldest cycle first, so the numbering does not shift
  /// as new cycles arrive.
  final int number;

  const _CycleCard({required this.analyzed, required this.number});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cycle = analyzed.cycle;
    final notes = describeCycle(evaluateCycle(cycle, analyzed.window));
    final subtitle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Tapping hands the cycle's first day back to the chart, which scrolls
        // there: the list explains a cycle, the chart shows it day by day.
        onTap: () => Navigator.of(context).pop(cycle.startDate),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      cycle.hasKnownStart
                          ? 'Cycle $number'
                          : 'Before the record',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '${cycle.length} day${cycle.length == 1 ? '' : 's'}',
                    style: subtitle,
                  ),
                ],
              ),
              Text(
                _dateRange(cycle.startDate, cycle.days.last.date),
                style: subtitle,
              ),
              const SizedBox(height: 10),
              CycleSparkline(analyzed: analyzed),
              const SizedBox(height: 12),
              for (final note in notes) _NoteLine(note: note),
            ],
          ),
        ),
      ),
    );
  }

  String _dateRange(DateTime from, DateTime to) {
    final start = from.year == to.year
        ? formatDayMonth(from)
        : formatDayMonthYear(from);
    return '$start - ${formatDayMonthYear(to)}';
  }
}

class _NoteLine extends StatelessWidget {
  final CycleNote note;

  const _NoteLine({required this.note});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (note.tone) {
      NoteTone.result => (
        Icons.check_circle_outline,
        theme.colorScheme.onSurface,
      ),
      NoteTone.step => (
        Icons.subdirectory_arrow_right,
        theme.colorScheme.onSurfaceVariant,
      ),
      NoteTone.advice => (Icons.lightbulb_outline, theme.colorScheme.primary),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note.text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
