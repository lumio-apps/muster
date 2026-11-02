import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../calc.dart';
import '../state.dart';
import '../theme.dart';
import 'common.dart';

/// Settings panel: company holidays (days off for everybody).
class HolidaysPanel extends StatefulWidget {
  const HolidaysPanel({super.key, required this.state});

  final AppState state;

  @override
  State<HolidaysPanel> createState() => _HolidaysPanelState();
}

class _HolidaysPanelState extends State<HolidaysPanel> {
  late int _year = widget.state.today.year;

  Future<void> _add() async {
    final s = widget.state;
    final res = await showDialog<(DateTime, String)>(
      context: context,
      builder: (_) => _AddHolidayDialog(initial: DateTime(_year, s.today.month, s.today.day)),
    );
    if (res == null) return;
    await s.addHoliday(res.$1, res.$2);
    if (mounted) setState(() => _year = res.$1.year);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final list =
            s.holidays.where((h) => h.date.startsWith('$_year-')).toList();
        return Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: PanelTitle(
                      'Company holidays',
                      subtitle: 'Days off for every worker, for example '
                          'public holidays.',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous year',
                    onPressed: () => setState(() => _year--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('$_year',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  IconButton(
                    tooltip: 'Next year',
                    onPressed: () => setState(() => _year++),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add holiday'),
                  ),
                ],
              ),
              if (list.isEmpty)
                Text('No holidays added for $_year.', style: kSubtle)
              else
                for (final h in list)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(
                            DateFormat('EEE, d MMM').format(parseDateKey(h.date)),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            h.name.isEmpty ? 'Holiday' : h.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => s.removeHoliday(h.date),
                          icon: const Icon(Icons.delete_outline, size: 18),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _AddHolidayDialog extends StatefulWidget {
  const _AddHolidayDialog({required this.initial});

  final DateTime initial;

  @override
  State<_AddHolidayDialog> createState() => _AddHolidayDialogState();
}

class _AddHolidayDialogState extends State<_AddHolidayDialog> {
  late DateTime _date = widget.initial;
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add holiday'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: fieldDec('Name (optional)', hint: 'New Year'),
              onSubmitted: (_) => Navigator.of(context).pop((_date, _name.text)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((_date, _name.text)),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
