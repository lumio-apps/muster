import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../currencies.dart';
import '../db.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import 'common.dart';

/// Add a new worker, or edit an existing one.
class WorkerFormPage extends StatefulWidget {
  const WorkerFormPage({super.key, required this.state, this.worker});

  final AppState state;
  final Worker? worker;

  @override
  State<WorkerFormPage> createState() => _WorkerFormPageState();
}

class _WorkerFormPageState extends State<WorkerFormPage> {
  final _form = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _role;
  late final TextEditingController _phone;
  late final TextEditingController _rate;
  late final TextEditingController _ot;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late final TextEditingController _break;
  late final TextEditingController _grace;

  late DateTime _joined;
  late PayType _payType;
  late bool _useCompany;
  late Set<int> _weeklyOff;
  late bool _active;
  String? _photoPath;
  bool _photoIsNew = false;
  bool _busy = false;

  bool get _isEdit => widget.worker != null;

  @override
  void initState() {
    super.initState();
    final s = widget.state;
    final w = widget.worker;
    _name = TextEditingController(text: w?.name ?? '');
    _role = TextEditingController(text: w?.role ?? '');
    _phone = TextEditingController(text: w?.phone ?? '');
    _rate = TextEditingController(text: w == null ? '' : fmtNum(w.rate));
    _ot = TextEditingController(
      text: fmtNum(w?.otMultiplier ?? s.otMultiplier),
    );
    _start = TextEditingController(text: w?.shiftStart ?? s.shiftStart);
    _end = TextEditingController(text: w?.shiftEnd ?? s.shiftEnd);
    _break = TextEditingController(
      text: '${w?.breakMinutes ?? s.breakMinutes}',
    );
    _grace = TextEditingController(text: '${w?.lateGrace ?? s.lateGrace}');
    _joined = w?.joinedOn ?? DateTime.now();
    _payType = w?.payType ?? PayType.daily;
    _useCompany = w?.useCompanyTiming ?? true;
    _weeklyOff = {...(w?.weeklyOff ?? s.weeklyOff)};
    _active = w?.active ?? true;
    _photoPath = w?.photoPath;
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _phone.dispose();
    _rate.dispose();
    _ot.dispose();
    _start.dispose();
    _end.dispose();
    _break.dispose();
    _grace.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image);
    if (!mounted) return;
    final path = (res == null || res.files.isEmpty) ? null : res.files.first.path;
    if (path != null) {
      setState(() {
        _photoPath = path;
        _photoIsNew = true;
      });
    }
  }

  void _removePhoto() {
    setState(() {
      _photoPath = null;
      _photoIsNew = false;
    });
  }

  Future<void> _pickJoined() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joined,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _joined = picked);
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      var photo = _photoPath;
      if (_photoIsNew && photo != null) {
        await Directory(AppPaths.photosDir).create(recursive: true);
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final ext = p.extension(photo).toLowerCase();
        final dest = p.join(AppPaths.photosDir, 'w_$stamp$ext');
        await File(photo).copy(dest);
        photo = dest;
      }

      final w = widget.worker ?? Worker(name: '');
      w.name = _name.text.trim();
      w.role = _role.text.trim();
      w.phone = _phone.text.trim();
      w.joinedOn = _joined;
      w.payType = _payType;
      w.rate = parseNum(_rate.text) ?? 0;
      w.otMultiplier = parseNum(_ot.text) ?? 1.5;
      w.useCompanyTiming = _useCompany;
      w.shiftStart = _start.text.trim();
      w.shiftEnd = _end.text.trim();
      w.breakMinutes = int.tryParse(_break.text.trim()) ?? 60;
      w.lateGrace = int.tryParse(_grace.text.trim()) ?? 10;
      w.weeklyOff = _weeklyOff;
      w.photoPath = photo;
      w.active = _active;

      if (_isEdit) {
        await widget.state.updateWorker(w);
      } else {
        await widget.state.addWorker(w);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMsg(context, 'Could not save the worker: $e');
    }
  }

  Widget _photoBlock() {
    final path = _photoPath;
    ImageProvider? img;
    if (path != null && File(path).existsSync()) {
      img = FileImage(File(path));
    }
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: kNavySoft,
          foregroundImage: img,
          child: const Icon(Icons.person, size: 44, color: kNavy),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _pickPhoto,
          icon: const Icon(Icons.photo_outlined, size: 18),
          label: Text(path == null ? 'Add photo' : 'Change photo'),
        ),
        if (path != null)
          TextButton(onPressed: _removePhoto, child: const Text('Remove')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit worker' : 'Add worker'),
        backgroundColor: kPanel,
        scrolledUnderElevation: 0,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Panel(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 160, child: _photoBlock()),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const PanelTitle('Basic details'),
                              TextFormField(
                                controller: _name,
                                decoration: fieldDec('Full name'),
                                validator: requiredValidator,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _role,
                                      decoration: fieldDec(
                                        'Role',
                                        hint: 'Mason, Helper, Driver…',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phone,
                                      decoration: fieldDec('Phone'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  const Text('Joining date', style: kSubtle),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    onPressed: _pickJoined,
                                    icon: const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      DateFormat('d MMM yyyy').format(_joined),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PanelTitle(
                          'Pay',
                          subtitle: 'How this worker is paid.',
                        ),
                        SegmentedButton<PayType>(
                          showSelectedIcon: false,
                          segments: [
                            for (final t in PayType.values)
                              ButtonSegment<PayType>(
                                value: t,
                                label: Text(t.label),
                              ),
                          ],
                          selected: <PayType>{_payType},
                          onSelectionChanged: (v) =>
                              setState(() => _payType = v.first),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _rate,
                                decoration: fieldDec(
                                  _payType.rateLabel,
                                  prefix: symbolPrefix(s.currency),
                                  suffix: _payType.suffix,
                                ),
                                validator: numberValidator,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _ot,
                                decoration: fieldDec(
                                  'Overtime rate',
                                  suffix: '× normal',
                                ),
                                validator: numberValidator,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PanelTitle('Work timing'),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Use company timing'),
                          subtitle: Text(
                            '${s.companyTiming.label}, '
                            '${s.breakMinutes} min break',
                            style: kSubtle,
                          ),
                          value: _useCompany,
                          onChanged: (v) => setState(() => _useCompany = v),
                        ),
                        if (!_useCompany) ...[
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _start,
                                  decoration:
                                      fieldDec('Work starts', hint: 'HH:mm'),
                                  validator: timeValidator,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _end,
                                  decoration:
                                      fieldDec('Work ends', hint: 'HH:mm'),
                                  validator: timeValidator,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _break,
                                  decoration:
                                      fieldDec('Break', suffix: 'minutes'),
                                  validator: intValidator,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _grace,
                                  decoration:
                                      fieldDec('Late grace', suffix: 'minutes'),
                                  validator: intValidator,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                        const Text(
                          'Weekly off',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        WeekdayChips(
                          selected: _weeklyOff,
                          onChanged: (next) =>
                              setState(() => _weeklyOff = next),
                        ),
                      ],
                    ),
                  ),
                  if (_isEdit) ...[
                    const SizedBox(height: 16),
                    Panel(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active worker'),
                        subtitle: const Text(
                          'Inactive workers are hidden from daily attendance. '
                          'Their past records are kept.',
                          style: kSubtle,
                        ),
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed:
                            _busy ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: Text(_isEdit ? 'Save changes' : 'Add worker'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
