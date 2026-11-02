import 'package:flutter/material.dart';

import '../currencies.dart';
import '../state.dart';
import '../theme.dart';
import 'common.dart';

/// Holds the text controllers shared by the setup wizard and Settings page.
class SettingsFormController {
  SettingsFormController(AppState s)
      : company = TextEditingController(text: s.companyName),
        owner = TextEditingController(text: s.ownerName),
        phone = TextEditingController(text: s.phone),
        address = TextEditingController(text: s.address),
        currencyCode = s.currencyCode,
        shiftStart = TextEditingController(text: s.shiftStart),
        shiftEnd = TextEditingController(text: s.shiftEnd),
        breakMin = TextEditingController(text: '${s.breakMinutes}'),
        grace = TextEditingController(text: '${s.lateGrace}'),
        ot = TextEditingController(text: fmtNum(s.otMultiplier)),
        paidLeave = s.paidLeave,
        lateFine = TextEditingController(
          text: s.lateFine == 0 ? '' : fmtNum(s.lateFine),
        ),
        holidayPaid = s.holidayPaid,
        weeklyOff = {...s.weeklyOff};

  final TextEditingController company;
  final TextEditingController owner;
  final TextEditingController phone;
  final TextEditingController address;
  final TextEditingController shiftStart;
  final TextEditingController shiftEnd;
  final TextEditingController breakMin;
  final TextEditingController grace;
  final TextEditingController ot;
  final TextEditingController lateFine;
  String currencyCode;
  Set<int> weeklyOff;
  bool paidLeave;
  bool holidayPaid;

  void dispose() {
    company.dispose();
    owner.dispose();
    phone.dispose();
    address.dispose();
    shiftStart.dispose();
    shiftEnd.dispose();
    breakMin.dispose();
    grace.dispose();
    ot.dispose();
    lateFine.dispose();
  }

  Map<String, String> toMap() {
    final days = weeklyOff.toList()..sort();
    return {
      'company_name': company.text.trim(),
      'owner_name': owner.text.trim(),
      'phone': phone.text.trim(),
      'address': address.text.trim(),
      'currency_code': currencyCode,
      'shift_start': shiftStart.text.trim(),
      'shift_end': shiftEnd.text.trim(),
      'break_minutes': breakMin.text.trim(),
      'late_grace': grace.text.trim(),
      'ot_multiplier': ot.text.trim(),
      'weekly_off': days.join(','),
      'paid_leave': paidLeave ? '1' : '0',
      'late_fine': lateFine.text.trim().isEmpty ? '0' : lateFine.text.trim(),
      'holiday_paid': holidayPaid ? '1' : '0',
    };
  }
}

class CompanyFields extends StatelessWidget {
  const CompanyFields({super.key, required this.c});

  final SettingsFormController c;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: c.company,
          decoration: fieldDec('Company name'),
          validator: requiredValidator,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: c.owner,
                decoration: fieldDec('Owner / manager name'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: c.phone,
                decoration: fieldDec('Phone'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: c.address,
          decoration: fieldDec('Address'),
        ),
        const SizedBox(height: 14),
        SizedBox(width: 380, child: CurrencyField(c: c)),
      ],
    );
  }
}

/// Field that opens a searchable list of currencies.
class CurrencyField extends StatefulWidget {
  const CurrencyField({super.key, required this.c});

  final SettingsFormController c;

  @override
  State<CurrencyField> createState() => _CurrencyFieldState();
}

class _CurrencyFieldState extends State<CurrencyField> {
  Future<void> _pick() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => _CurrencyDialog(selected: widget.c.currencyCode),
    );
    if (code != null && mounted) {
      setState(() => widget.c.currencyCode = code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = currencyByCode(widget.c.currencyCode);
    return InkWell(
      onTap: _pick,
      child: InputDecorator(
        decoration: fieldDec('Currency').copyWith(
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text('${cur.symbol}   ${cur.code} – ${cur.name}'),
      ),
    );
  }
}

class _CurrencyDialog extends StatefulWidget {
  const _CurrencyDialog({required this.selected});

  final String selected;

  @override
  State<_CurrencyDialog> createState() => _CurrencyDialogState();
}

class _CurrencyDialogState extends State<_CurrencyDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final list = kCurrencies.where((c) {
      if (q.isEmpty) return true;
      return c.code.toLowerCase().contains(q) ||
          c.name.toLowerCase().contains(q) ||
          c.symbol.toLowerCase().contains(q);
    }).toList();

    return AlertDialog(
      title: const Text('Choose currency'),
      content: SizedBox(
        width: 440,
        height: 460,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: fieldDec('Search currency or code').copyWith(
                prefixIcon: const Icon(Icons.search, size: 18),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Text('No currency found.', style: kSubtle),
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final c = list[i];
                        return ListTile(
                          dense: true,
                          selected: c.code == widget.selected,
                          leading: SizedBox(
                            width: 48,
                            child: Text(
                              c.symbol,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          title: Text('${c.code} – ${c.name}'),
                          onTap: () => Navigator.of(context).pop(c.code),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class WorkRulesFields extends StatefulWidget {
  const WorkRulesFields({super.key, required this.c});

  final SettingsFormController c;

  @override
  State<WorkRulesFields> createState() => _WorkRulesFieldsState();
}

class _WorkRulesFieldsState extends State<WorkRulesFields> {
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: c.shiftStart,
                decoration: fieldDec('Work starts', hint: 'HH:mm'),
                validator: timeValidator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: c.shiftEnd,
                decoration: fieldDec('Work ends', hint: 'HH:mm'),
                validator: timeValidator,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: c.breakMin,
                decoration: fieldDec('Break', suffix: 'minutes'),
                validator: intValidator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: c.grace,
                decoration: fieldDec('Late grace', suffix: 'minutes'),
                validator: intValidator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: c.ot,
                decoration: fieldDec('Overtime rate', suffix: '× normal'),
                validator: numberValidator,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 300,
          child: TextFormField(
            controller: c.lateFine,
            decoration: fieldDec(
              'Fine for each late arrival',
              hint: '0 = no fine',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? null : numberValidator(v),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'A worker is late when check-in is after work start plus the late '
          'grace. The fine is taken from salary for every late day.',
          style: kSubtle,
        ),
        const SizedBox(height: 18),
        const Text(
          'Weekly off',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        WeekdayChips(
          selected: c.weeklyOff,
          onChanged: (next) => setState(() => c.weeklyOff = next),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Leave (L) is paid'),
          subtitle: const Text(
            'Switch off to treat leave days as unpaid in salary.',
            style: kSubtle,
          ),
          value: c.paidLeave,
          onChanged: (v) => setState(() => c.paidLeave = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Company holidays are paid'),
          subtitle: const Text(
            'Daily and hourly workers get a paid day for each company '
            'holiday. Monthly workers are always paid.',
            style: kSubtle,
          ),
          value: c.holidayPaid,
          onChanged: (v) => setState(() => c.holidayPaid = v),
        ),
      ],
    );
  }
}
