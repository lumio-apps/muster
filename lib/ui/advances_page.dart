import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../calc.dart';
import '../currencies.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import 'common.dart';

/// Advance (peshgi) given to workers, and what each worker still owes.
class AdvancesPage extends StatefulWidget {
  const AdvancesPage({super.key, required this.state});

  final AppState state;

  @override
  State<AdvancesPage> createState() => _AdvancesPageState();
}

class _AdvancesPageState extends State<AdvancesPage> {
  int? _filter;

  Future<void> _give() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _GiveDialog(state: widget.state),
    );
  }

  Future<void> _delete(Advance a, String workerName) async {
    final ok = await confirm(
      context,
      title: 'Delete this advance?',
      message: 'Remove the ${fmtMoney(a.amount, widget.state.currency)} '
          'advance given to $workerName on ${a.date}? '
          'Use this only to correct a mistake.',
      yes: 'Delete',
    );
    if (!ok || !mounted) return;
    await widget.state.removeAdvance(a);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final byId = {for (final w in s.workers) w.id!: w};
        final entries = s.advances
            .where((a) => _filter == null || a.workerId == _filter)
            .toList();

        final balances = <MapEntry<Worker, double>>[];
        var outstanding = 0.0;
        for (final w in s.workers) {
          final b = s.balanceOf(w.id!);
          if (b > 0) {
            balances.add(MapEntry(w, b));
            outstanding += b;
          }
        }
        balances.sort((x, y) => y.value.compareTo(x.value));

        final thisMonth = monthKey(s.today);
        var givenThisMonth = 0.0;
        for (final a in s.advances) {
          if (a.date.startsWith(thisMonth)) givenThisMonth += a.amount;
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Advances', style: kTitle),
                  const Spacer(),
                  DropdownButton<int?>(
                    value: _filter,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All workers'),
                      ),
                      for (final w in s.workers)
                        DropdownMenuItem<int?>(
                          value: w.id,
                          child: Text(w.name),
                        ),
                    ],
                    onChanged: (v) => setState(() => _filter = v),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _give,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Give advance'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Tile(
                    'Total pending',
                    fmtMoney(outstanding, s.currency),
                    kOrange,
                    kOrangeSoft,
                  ),
                  _Tile(
                    'Workers with advance',
                    '${balances.length}',
                    kNavy,
                    kNavySoft,
                  ),
                  _Tile(
                    'Given this month',
                    fmtMoney(givenThisMonth, s.currency),
                    kBlue,
                    kBlueSoft,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: entries.isEmpty
                          ? const Panel(
                              child: Center(
                                child: Text(
                                  'No advances yet. Click "Give advance" '
                                  'to record one.',
                                  style: kSubtle,
                                ),
                              ),
                            )
                          : Panel(
                              padding: EdgeInsets.zero,
                              child: ListView.separated(
                                itemCount: entries.length,
                                separatorBuilder: (context, i) =>
                                    const Divider(height: 1, color: kBorder),
                                itemBuilder: (context, i) {
                                  final a = entries[i];
                                  final w = byId[a.workerId];
                                  return _EntryRow(
                                    advance: a,
                                    worker: w,
                                    currency: s.currency,
                                    onDelete: () => _delete(
                                      a,
                                      w?.name ?? 'this worker',
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Panel(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                              child: Text(
                                'Pending balance',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Divider(height: 1, color: kBorder),
                            Expanded(
                              child: balances.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No pending advance.',
                                        style: kSubtle,
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: balances.length,
                                      separatorBuilder: (context, i) =>
                                          const Divider(
                                        height: 1,
                                        color: kBorder,
                                      ),
                                      itemBuilder: (context, i) {
                                        final e = balances[i];
                                        return InkWell(
                                          onTap: () => setState(
                                            () => _filter = e.key.id,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                            child: Row(
                                              children: [
                                                WorkerAvatar(
                                                  worker: e.key,
                                                  size: 30,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    e.key.name,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  fmtMoney(
                                                    e.value,
                                                    s.currency,
                                                  ),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: kOrange,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pending advance is deducted when you mark a salary as paid '
                'on the Salary page.',
                style: kSubtle,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, this.color, this.background);

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.advance,
    required this.worker,
    required this.currency,
    required this.onDelete,
  });

  final Advance advance;
  final Worker? worker;
  final String currency;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final w = worker;
    final date = DateFormat('d MMM yyyy').format(parseDateKey(advance.date));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(date)),
          if (w != null) ...[
            WorkerAvatar(worker: w, size: 30),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  w?.name ?? 'Unknown worker',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (advance.note.isNotEmpty)
                  Text(advance.note, style: kSubtle),
              ],
            ),
          ),
          Text(
            fmtMoney(advance.amount, currency),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          IconButton(
            tooltip: 'Delete (to fix a mistake)',
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }
}

class _GiveDialog extends StatefulWidget {
  const _GiveDialog({required this.state});

  final AppState state;

  @override
  State<_GiveDialog> createState() => _GiveDialogState();
}

class _GiveDialogState extends State<_GiveDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late DateTime _date = widget.state.today;
  int? _workerId;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final list = widget.state.workers.where((w) => w.active).toList();
    if (list.isNotEmpty) _workerId = list.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: widget.state.today,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = parseNum(_amount.text);
    final id = _workerId;
    if (id == null) {
      setState(() => _error = 'Choose a worker.');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    final worker = widget.state.workers.firstWhere((w) => w.id == id);
    setState(() => _busy = true);
    await widget.state.giveAdvance(
      worker,
      (amount * 100).roundToDouble() / 100,
      _date,
      _note.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final workers = widget.state.workers.where((w) => w.active).toList();
    return AlertDialog(
      title: const Text('Give advance'),
      content: SizedBox(
        width: 400,
        child: workers.isEmpty
            ? const Text('Add a worker first.', style: kSubtle)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Worker', style: kSubtle),
                  DropdownButton<int>(
                    value: _workerId,
                    isExpanded: true,
                    items: [
                      for (final w in workers)
                        DropdownMenuItem<int>(
                          value: w.id,
                          child: Text('${w.name} (${w.code})'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _workerId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amount,
                    decoration: fieldDec(
                      'Amount',
                      prefix: symbolPrefix(widget.state.currency),
                    ),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Date', style: kSubtle),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                        label: Text(DateFormat('d MMM yyyy').format(_date)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _note,
                    decoration: fieldDec('Note (optional)'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: kRed, fontSize: 12),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (workers.isNotEmpty)
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save advance'),
          ),
      ],
    );
  }
}
