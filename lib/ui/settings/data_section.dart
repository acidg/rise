import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

import '../app_controller.dart';

/// Export the history to a CSV file the user saves through the system dialog, and
/// import one back.
///
/// Export uses a "create document" dialog so the file lands wherever the user
/// chooses (local storage, Drive, any provider) rather than a share sheet, which
/// only offers send targets. The paired thermometer is not part of the history
/// and is never exported; see [AppController.exportCsv]. Import asks before
/// replacing a day that already exists with different contents.
class DataSection extends StatefulWidget {
  final AppController controller;

  const DataSection({super.key, required this.controller});

  @override
  State<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<DataSection> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final csv = await widget.controller.exportCsv();
      final saved = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          data: utf8.encode(csv),
          fileName: _exportFileName(),
          mimeTypesFilter: const ['text/csv'],
        ),
      );
      // A null path means the user backed out of the save dialog.
      if (saved != null) {
        _showMessage('History exported.');
      }
    } on Object catch (error) {
      _showError('Export failed: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _import() async {
    const csvType = XTypeGroup(
      label: 'CSV',
      extensions: ['csv'],
      mimeTypes: ['text/csv', 'text/comma-separated-values'],
    );
    final file = await openFile(acceptedTypeGroups: const [csvType]);
    if (file == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final csv = await file.readAsString();
      final result = await widget.controller.importCsv(
        csv,
        resolveConflict: _confirmReplace,
      );
      _showMessage(_summary(result));
    } on FormatException catch (error) {
      _showError('Could not read that file: ${error.message}');
    } on Object catch (error) {
      _showError('Import failed: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Ask whether an imported entry should replace the differing stored one.
  /// Returns false (keep the stored entry) when the screen is gone or the dialog
  /// is dismissed, so an existing day is never overwritten without a yes.
  Future<bool> _confirmReplace(EntryConflict conflict) async {
    if (!mounted) {
      return false;
    }
    final date = MaterialLocalizations.of(context).formatMediumDate(conflict.day);
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace entry?'),
        content: Text(
          'The import has different data for $date than what is already saved. '
          'Replace the saved entry with the imported one?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep saved'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return replace ?? false;
  }

  String _summary(ImportResult result) {
    if (result.total == 0) {
      return 'The file had no entries to import.';
    }
    final parts = <String>[];
    if (result.added > 0) {
      parts.add('${result.added} added');
    }
    if (result.replaced > 0) {
      parts.add('${result.replaced} replaced');
    }
    if (result.skipped > 0) {
      parts.add('${result.skipped} unchanged');
    }
    return 'Imported: ${parts.join(', ')}.';
  }

  String _exportFileName() {
    final now = DateTime.now();
    String pad(int value) => value.toString().padLeft(2, '0');
    return 'rise-history-${now.year}${pad(now.month)}${pad(now.day)}.csv';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) => _showMessage(message);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Export your history to a CSV file to back it up or move it to another '
          'phone, or import one you saved earlier. Your paired thermometer is not '
          'part of the file.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.upload_file),
              label: const Text('Export'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _import,
              icon: const Icon(Icons.download),
              label: const Text('Import'),
            ),
          ],
        ),
      ],
    );
  }
}
