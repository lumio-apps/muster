import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state.dart';
import '../theme.dart';
import 'common.dart';

/// Shown instead of the app while the PIN lock is active.
class LockPage extends StatefulWidget {
  const LockPage({super.key, required this.state});

  final AppState state;

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  final _pin = TextEditingController();
  String? _error;
  int _fails = 0;
  DateTime? _blockedUntil;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final until = _blockedUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      final secs = until.difference(DateTime.now()).inSeconds + 1;
      setState(() => _error = 'Too many wrong tries. Wait $secs seconds.');
      return;
    }
    final pin = _pin.text.trim();
    if (pin.isEmpty) return;

    setState(() => _busy = true);
    final ok = await widget.state.tryUnlock(pin);
    if (!mounted || ok) return;

    _fails++;
    _pin.clear();
    var message = 'Wrong PIN.';
    if (_fails >= 5) {
      _blockedUntil = DateTime.now().add(const Duration(seconds: 30));
      _fails = 0;
      message = 'Too many wrong tries. Wait 30 seconds.';
    }
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  Future<void> _forgot() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _RecoveryEntryDialog(state: widget.state),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 380,
          child: Panel(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MusterLogo(size: 56),
                const SizedBox(height: 14),
                const Text('Muster is locked', style: kTitle),
                const SizedBox(height: 4),
                const Text('Enter your PIN to continue.', style: kSubtle),
                const SizedBox(height: 18),
                TextField(
                  controller: _pin,
                  autofocus: true,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: fieldDec('PIN'),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: kRed, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: const Text('Unlock'),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _forgot,
                  child: const Text('Forgot PIN?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecoveryEntryDialog extends StatefulWidget {
  const _RecoveryEntryDialog({required this.state});

  final AppState state;

  @override
  State<_RecoveryEntryDialog> createState() => _RecoveryEntryDialogState();
}

class _RecoveryEntryDialogState extends State<_RecoveryEntryDialog> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (_code.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final ok = await widget.state.resetWithRecovery(_code.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = 'This recovery code is not correct.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Forgot PIN'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the recovery code that was shown when you set the PIN. '
              'The PIN lock will be turned off, and you can set a new PIN in '
              'Settings.',
              style: kSubtle,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              autofocus: true,
              decoration: fieldDec('Recovery code', hint: 'XXXX-XXXX-XXXX'),
              onSubmitted: (_) => _reset(),
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
        FilledButton(
          onPressed: _busy ? null : _reset,
          child: const Text('Turn off PIN'),
        ),
      ],
    );
  }
}
