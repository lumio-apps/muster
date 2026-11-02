import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import 'common.dart';
import 'worker_form_page.dart';

/// List of all workers with search; tap a row to edit.
class WorkersPage extends StatefulWidget {
  const WorkersPage({super.key, required this.state});

  final AppState state;

  @override
  State<WorkersPage> createState() => _WorkersPageState();
}

class _WorkersPageState extends State<WorkersPage> {
  String _query = '';
  bool _showInactive = false;

  void _open({Worker? worker}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkerFormPage(state: widget.state, worker: worker),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final q = _query.trim().toLowerCase();
        final list = state.workers.where((w) {
          if (!_showInactive && !w.active) return false;
          if (q.isEmpty) return true;
          return w.name.toLowerCase().contains(q) ||
              w.role.toLowerCase().contains(q) ||
              w.phone.contains(q) ||
              w.code.toLowerCase().contains(q);
        }).toList();
        final activeCount = state.workers.where((w) => w.active).length;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Workers', style: kTitle),
                  const SizedBox(width: 10),
                  Pill(
                    text: '$activeCount active',
                    color: kNavy,
                    background: kNavySoft,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      decoration: fieldDec('Search name, role, phone').copyWith(
                        prefixIcon: const Icon(Icons.search, size: 18),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: const Text('Show inactive'),
                    selected: _showInactive,
                    onSelected: (v) => setState(() => _showInactive = v),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _open(),
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Add worker'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: list.isEmpty
                    ? Panel(
                        child: Center(
                          child: Text(
                            state.workers.isEmpty
                                ? 'No workers yet. Click "Add worker" to begin.'
                                : 'No workers match your search.',
                            style: kSubtle,
                          ),
                        ),
                      )
                    : Panel(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            const _HeaderRow(),
                            const Divider(height: 1, color: kBorder),
                            Expanded(
                              child: ListView.separated(
                                itemCount: list.length,
                                separatorBuilder: (context, i) =>
                                    const Divider(height: 1, color: kBorder),
                                itemBuilder: (context, i) => _WorkerRow(
                                  state: state,
                                  worker: list[i],
                                  onTap: () => _open(worker: list[i]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: kMuted,
    );
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 50),
          Expanded(flex: 3, child: Text('NAME', style: style)),
          Expanded(flex: 2, child: Text('ROLE', style: style)),
          Expanded(flex: 2, child: Text('PHONE', style: style)),
          Expanded(flex: 2, child: Text('PAY', style: style)),
          Expanded(flex: 2, child: Text('TIMING', style: style)),
          SizedBox(width: 80, child: Text('STATUS', style: style)),
        ],
      ),
    );
  }
}

class _WorkerRow extends StatelessWidget {
  const _WorkerRow({
    required this.state,
    required this.worker,
    required this.onTap,
  });

  final AppState state;
  final Worker worker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = worker;
    final t = state.timingFor(w);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            WorkerAvatar(worker: w, size: 36),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(w.code, style: kSubtle),
                ],
              ),
            ),
            Expanded(flex: 2, child: Text(w.role.isEmpty ? '–' : w.role)),
            Expanded(flex: 2, child: Text(w.phone.isEmpty ? '–' : w.phone)),
            Expanded(
              flex: 2,
              child: Text(
                '${fmtMoney(w.rate, state.currency)} ${w.payType.suffix}',
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                w.useCompanyTiming ? 'Company timing' : t.label,
                style: kSubtle,
              ),
            ),
            SizedBox(
              width: 80,
              child: w.active
                  ? const Pill(
                      text: 'Active',
                      color: kGreen,
                      background: kGreenSoft,
                    )
                  : const Pill(
                      text: 'Inactive',
                      color: kMuted,
                      background: kGreySoft,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
