import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import 'common.dart';
import 'settings_forms.dart';

/// First-time setup wizard: company details, then work rules, then done.
class SetupPage extends StatefulWidget {
  const SetupPage({super.key, required this.state});

  final AppState state;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  late final SettingsFormController _c = SettingsFormController(widget.state);
  final List<GlobalKey<FormState>> _keys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];
  int _step = 0;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _back() => setState(() => _step -= 1);

  Future<void> _next() async {
    if (_step < 2) {
      if (!(_keys[_step].currentState?.validate() ?? false)) return;
      setState(() => _step += 1);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.state.completeSetup(_c.toMap());
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMsg(context, 'Could not save your settings: $e');
    }
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return Form(
          key: _keys[0],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PanelTitle(
                'Your company',
                subtitle: 'This appears on your reports and salary slips.',
              ),
              CompanyFields(c: _c),
            ],
          ),
        );
      case 1:
        return Form(
          key: _keys[1],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PanelTitle(
                'Work rules',
                subtitle:
                    'Default timing for all workers. You can give any worker '
                    'their own timing later.',
              ),
              WorkRulesFields(c: _c),
            ],
          ),
        );
      default:
        final off = _c.weeklyOff.toList()..sort();
        final offText = off.isEmpty
            ? 'None'
            : off.map((d) => kWeekdayLong[d - 1]).join(', ');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PanelTitle(
              'You are all set',
              subtitle: 'Please check the details below.',
            ),
            _SummaryRow('Company', _c.company.text.trim()),
            _SummaryRow(
              'Working hours',
              '${_c.shiftStart.text.trim()} – ${_c.shiftEnd.text.trim()}',
            ),
            _SummaryRow('Break', '${_c.breakMin.text.trim()} minutes'),
            _SummaryRow('Weekly off', offText),
            const SizedBox(height: 12),
            const Text(
              'You can change all of this later in Settings. '
              'Next, add your workers and start marking attendance.',
              style: kSubtle,
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == 2;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    MusterLogo(size: 48),
                    SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome to Muster', style: kTitle),
                        Text(
                          'Attendance and salary, made simple. '
                          'Let us set up in two minutes.',
                          style: kSubtle,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= _step ? kAmber : kBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (i < 2) const SizedBox(width: 6),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text('Step ${_step + 1} of 3', style: kSubtle),
                const SizedBox(height: 12),
                Panel(child: _stepBody()),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_step > 0)
                      OutlinedButton(
                        onPressed: _busy ? null : _back,
                        child: const Text('Back'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _busy ? null : _next,
                      child: Text(isLast ? 'Start using Muster' : 'Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: kSubtle)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
