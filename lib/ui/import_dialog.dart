import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../import_workers.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../xlsx_reader.dart';
import 'common.dart';

/// Adds many workers from an Excel (.xlsx) or CSV file.
class ImportWorkersDialog extends StatefulWidget {
  const ImportWorkersDialog({super.key, required this.state});

  final AppState state;

  @override
  State<ImportWorkersDialog> createState() => _ImportWorkersDialogState();
}

class _ImportWorkersDialogState extends State<ImportWorkersDialog> {
  ImportPreview? _preview;
  String _fileName = '';
  String? _problem;
  bool _busy = false;

  Future<void> _saveSample() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save sample file',
      fileName: 'Muster-workers-sample.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return;
    final fixed = path.toLowerCase().endsWith('.csv') ? path : '$path.csv';
    try {
      await File(fixed).writeAsString('﻿$kSampleWorkersCsv');
      if (mounted) showMsg(context, 'Sample saved: $fixed');
    } catch (e) {
      if (mounted) showMsg(context, 'Could not save the sample: $e');
    }
  }

  Future<void> _choose() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );
    final path =
        (res == null || res.files.isEmpty) ? null : res.files.first.path;
    if (path == null) return;

    setState(() {
      _busy = true;
      _problem = null;
      _preview = null;
    });
    try {
      final bytes = Uint8List.fromList(await File(path).readAsBytes());
      List<List<String>> rows;
      if (path.toLowerCase().endsWith('.xlsx')) {
        rows = readXlsxFirstSheet(bytes);
      } else {
        rows = parseCsv(_decodeText(bytes));
      }
      final s = widget.state;
      final preview = buildImportPreview(
        rows,
        existingNames: s.workers.map((w) => w.name),
        today: s.today,
        defaultOvertime: s.otMultiplier,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _fileName = path.split(RegExp(r'[\\/]')).last;
        _preview = preview;
        _problem = preview.headerProblem;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = 'This file could not be read. Save it again as .xlsx or '
            '.csv and try once more.';
      });
    }
  }

  /// UTF-8 text, falling back to Latin-1 for old Excel CSV files.
  String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  Future<void> _import() async {
    final p = _preview;
    if (p == null || p.workers.isEmpty) return;
    setState(() => _busy = true);
    final n = await widget.state.importWorkers(p.workers);
    if (!mounted) return;
    Navigator.of(context).pop();
    showMsg(context, '$n workers added.');
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return AlertDialog(
      title: const Text('Import workers'),
      content: SizedBox(
        width: 620,
        height: 460,
        child: ListView(
          children: [
            const Text(
              'Add many workers at once from an Excel (.xlsx) or CSV file. '
              'The first row must be a header. Required columns: Name and '
              'Rate. Optional: Role, Phone, Pay type (daily, monthly, '
              'hourly), Joined on (yyyy-mm-dd) and Overtime rate.',
              style: kSubtle,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _choose,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Choose file'),
                ),
                OutlinedButton.icon(
                  onPressed: _saveSample,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Save sample file'),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_problem != null) ...[
              const SizedBox(height: 12),
              Text(_problem!, style: const TextStyle(color: kRed)),
            ],
            if (p != null && _problem == null) ...[
              const SizedBox(height: 16),
              Text(
                '$_fileName: ${p.workers.length} to add'
                '${p.errors.isEmpty ? '' : ', ${p.errors.length} skipped'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              for (final w in p.workers.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(w.name)),
                      Expanded(
                        flex: 2,
                        child: Text(w.role.isEmpty ? '-' : w.role, style: kSubtle),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${fmtMoney(w.rate, widget.state.currency)} '
                          '${w.payType.suffix}',
                          style: kSubtle,
                        ),
                      ),
                    ],
                  ),
                ),
              if (p.workers.length > 8)
                Text('… and ${p.workers.length - 8} more', style: kSubtle),
              if (p.errors.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Skipped rows',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: kOrange,
                  ),
                ),
                const SizedBox(height: 4),
                for (final e in p.errors.take(12))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      'Row ${e.line}: ${e.message}',
                      style: kSubtle,
                    ),
                  ),
                if (p.errors.length > 12)
                  Text('… and ${p.errors.length - 12} more', style: kSubtle),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_busy || p == null || p.workers.isEmpty) ? null : _import,
          child: Text(
            p == null || p.workers.isEmpty
                ? 'Import'
                : 'Import ${p.workers.length} workers',
          ),
        ),
      ],
    );
  }
}
