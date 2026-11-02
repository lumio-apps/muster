import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state.dart';
import '../theme.dart';
import 'common.dart';

/// Settings panel: PIN lock and auto-lock.
class SecurityPanel extends StatefulWidget {
  const SecurityPanel({super.key, required this.state});

  final AppState state;

  @override
  State<SecurityPanel> createState() => _SecurityPanelState();
}

class _SecurityPanelState extends State<SecurityPanel> {
  static const List<int> _minutes = [0, 5, 15, 30, 60];

  Future<void> _setPin() async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _NewPinDialog(),
    );
    if (pin == null || !mounted) return;
    final code = await widget.state.setPin(pin);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RecoveryDialog(code: code),
    );
  }

  Future<bool> _verify(String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _VerifyPinDialog(state: widget.state, title: title),
    );
    return ok ?? false;
  }

  Future<void> _change() async {
    if (!await _verify('Enter your current PIN')) return;
    if (!mounted) return;
    await _setPin();
  }

  Future<void> _remove() async {
    if (!await _verify('Enter your PIN to turn it off')) return;
    await widget.state.removePin();
    if (!mounted) return;
    showMsg(context, 'PIN lock is off.');
  }

  String _label(int m) => m == 0 ? 'Never' : 'After $m minutes';

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final on = s.pinEnabled;
        final current = _minutes.contains(s.autoLockMinutes)
            ? s.autoLockMinutes
            : 0;
        return Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: PanelTitle(
                      'PIN lock',
                      subtitle:
                          'Ask for a PIN when Muster opens, and after the '
                          'computer is left idle.',
                    ),
                  ),
                  if (on)
                    const Pill(
                      text: 'ON',
                      color: kGreen,
                      background: kGreenSoft,
                    )
                  else
                    const Pill(
                      text: 'OFF',
                      color: kMuted,
                      background: kGreySoft,
                    ),
                ],
              ),
              if (!on)
                FilledButton.icon(
                  onPressed: _setPin,
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Set PIN'),
                )
              else ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _change,
                      child: const Text('Change PIN'),
                    ),
                    OutlinedButton(
                      onPressed: _remove,
                      child: const Text('Turn off PIN'),
                    ),
                    const SizedBox(width: 10),
                    const Text('Lock automatically:', style: kSubtle),
                    DropdownButton<int>(
                      value: current,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final m in _minutes)
                          DropdownMenuItem<int>(
                            value: m,
                            child: Text(_label(m)),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) s.setAutoLock(v);
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'The PIN keeps other people out of the Muster window. It does '
                'not encrypt the data file, so also keep your Windows login '
                'protected. Keep the recovery code safe: it is the only way '
                'to remove a forgotten PIN.',
                style: kSubtle,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NewPinDialog extends StatefulWidget {
  const _NewPinDialog();

  @override
  State<_NewPinDialog> createState() => _NewPinDialogState();
}

class _NewPinDialogState extends State<_NewPinDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _ok() {
    final a = _a.text.trim();
    if (a.length < 4 || a.length > 8) {
      setState(() => _error = 'Use 4 to 8 digits.');
      return;
    }
    if (a != _b.text.trim()) {
      setState(() => _error = 'The two PINs do not match.');
      return;
    }
    Navigator.of(context).pop(a);
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: const Text('Set a PIN'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _a,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              decoration: fieldDec('New PIN (4 to 8 digits)'),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _b,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              decoration: fieldDec('Repeat PIN'),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _ok(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: kRed, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _ok, child: const Text('Set PIN')),
      ],
    );
  }
}

class _VerifyPinDialog extends StatefulWidget {
  const _VerifyPinDialog({required this.state, required this.title});

  final AppState state;
  final String title;

  @override
  State<_VerifyPinDialog> createState() => _VerifyPinDialogState();
}

class _VerifyPinDialogState extends State<_VerifyPinDialog> {
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_pin.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final ok = await widget.state.verifyPin(_pin.text.trim());
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = 'Wrong PIN.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _pin,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: fieldDec('PIN'),
              onSubmitted: (_) => _check(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: kRed, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _check,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _RecoveryDialog extends StatefulWidget {
  const _RecoveryDialog({required this.code});

  final String code;

  @override
  State<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<_RecoveryDialog> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save your recovery code'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If you forget your PIN, this code is the only way to unlock '
              'Muster. It is shown only once. Write it down or keep it in a '
              'safe place.',
              style: kSubtle,
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: kNavySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: SelectableText(
                  widget.code,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: kNavy,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: widget.code));
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _saved,
              onChanged: (v) => setState(() => _saved = v ?? false),
              title: const Text('I have saved this code'),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _saved ? () => Navigator.of(context).pop() : null,
          child: const Text('Done'),
        ),
      ],
    );
  }
}
