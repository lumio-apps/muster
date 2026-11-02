import 'package:flutter/material.dart';

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
        currency = TextEditingController(text: s.currency),
        shiftStart = TextEditingController(text: s.shiftStart),
        shiftEnd = TextEditingController(text: s.shiftEnd),
        breakMin = TextEditingController(text: '${s.breakMinutes}'),
        grace = TextEditingController(text: '${s.lateGrace}'),
        ot = TextEditingController(text: fmtNum(s.otMultiplier)),
        paidLeave = s.paidLeave,
        weeklyOff = {...s.weeklyOff};

  final TextEditingController company;
  final TextEditingController owner;
  final TextEditingController phone;
  final TextEditingController address;
  final TextEditingController currency;
  final TextEditingController shiftStart;
  final TextEditingController shiftEnd;
  final TextEditingController breakMin;
  final TextEditingController grace;
  final TextEditingController ot;
  Set<int> weeklyOff;
  bool paidLeave;

  void dispose() {
    company.dispose();
    owner.dispose();
    phone.dispose();
    address.dispose();
    currency.dispose();
    shiftStart.dispose();
    shiftEnd.dispose();
    breakMin.dispose();
    grace.dispose();
    ot.dispose();
  }

  Map<String, String> toMap() {
    final days = weeklyOff.toList()..sort();
    return {
      'company_name': company.text.trim(),
      'owner_name': owner.text.trim(),
      'phone': phone.text.trim(),
      'address': address.text.trim(),
      'currency': currency.text.trim().isEmpty ? '₹' : currency.text.trim(),
      'shift_start': shiftStart.text.trim(),
      'shift_end': shiftEnd.text.trim(),
      'break_minutes': breakMin.text.trim(),
      'late_grace': grace.text.trim(),
      'ot_multiplier': ot.text.trim(),
      'weekly_off': days.join(','),
      'paid_leave': paidLeave ? '1' : '0',
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
        SizedBox(
          width: 200,
          child: TextFormField(
            controller: c.currency,
            decoration: fieldDec('Currency symbol', hint: '₹'),
          ),
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
      ],
    );
  }
}
