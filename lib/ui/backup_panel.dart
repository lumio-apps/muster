import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../backup.dart';
import '../calc.dart';
import '../state.dart';
import '../theme.dart';
import 'common.dart';

/// Settings panel: password-protected backup and restore.
class BackupPanel extends StatefulWidget {
  const BackupPanel({super.key, required this.state});

  final AppState state;

  @override
  State<BackupPanel> createState() => _BackupPanelState();
}

class _BackupPanelState extends State<BackupPanel> {
  bool _busy = false;
  String _status = '';

  Future<void> _create() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(
        confirm: true,
        title: 'Protect the backup with a password',
        message: 'If you forget this password, the backup can never be '
            'opened. Nobody, not even the Muster developer, can recover it. '
            'Write it down.',
      ),
    );
    if (password == null || !mounted) return;

    final name = 'Muster-backup_${dateKey(DateTime.now())}.mbk';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save backup',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: ['mbk'],
    );
    if (path == null || !mounted) return;
    final fixed = path.toLowerCase().endsWith('.mbk') ? path : '$path.mbk';

    setState(() {
      _busy = true;
      _status = 'Creating the backup. This can take a few seconds…';
    });
    try {
      final info = await PackageInfo.fromPlatform();
      final size = await BackupService.create(
        db: widget.state.db,
        password: password,
        destPath: fixed,
        appVersion: info.version,
      );
      await widget.state.markBackupDone();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '';
      });
      final mb = (size / 1048576).toStringAsFixed(1);
      showMsg(context, 'Backup saved ($mb MB): $fixed');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '';
      });
      showMsg(context, 'Backup failed: $e');
    }
  }

  Future<void> _restore() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mbk'],
    );
    final path =
        (res == null || res.files.isEmpty) ? null : res.files.first.path;
    if (path == null || !mounted) return;

    final ok = await confirm(
      context,
      title: 'Replace all current data?',
      message: 'All workers, attendance, advances and salaries in Muster will '
          'be replaced by this backup. Your current data is first moved to a '
          'safety folder inside the Muster data folder, so nothing is lost. '
          'Muster will restart.',
      yes: 'Continue',
    );
    if (!ok || !mounted) return;

    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(
        confirm: false,
        title: 'Backup password',
        message: 'Enter the password you used when you created this backup.',
      ),
    );
    if (password == null || !mounted) return;

    setState(() {
      _busy = true;
      _status = 'Restoring. Muster will restart when it is done…';
    });
    try {
      await BackupService.restore(
        db: widget.state.db,
        backupPath: path,
        password: password,
      );
    } on BackupException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '';
      });
      showMsg(context, e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '';
      });
      showMsg(context, 'Restore failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final last = s.lastBackup;
        var note = 'No backup made yet. Make one now.';
        var noteColor = kOrange;
        if (last != null) {
          final days = s.today.difference(parseDateKey(last)).inDays;
          note = days <= 0
              ? 'Last backup: today.'
              : 'Last backup: $last ($days days ago).';
          noteColor = days > 30 ? kOrange : kMuted;
        }
        return Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PanelTitle(
                'Backup and restore',
                subtitle: 'One password-protected file with all your data '
                    'and worker photos.',
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _create,
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: const Text('Create backup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _restore,
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Restore from backup'),
                  ),
                ],
              ),
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
                const SizedBox(height: 6),
                Text(_status, style: kSubtle),
              ],
              const SizedBox(height: 12),
              Text(note, style: TextStyle(color: noteColor, fontSize: 13)),
              const SizedBox(height: 4),
              const Text(
                'Keep a copy of the backup on another drive or USB stick. '
                'Backup files are encrypted with AES-256.',
                style: kSubtle,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({
    required this.confirm,
    required this.title,
    required this.message,
  });

  final bool confirm;
  final String title;
  final String message;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _ok() {
    final a = _a.text;
    if (widget.confirm) {
      if (a.length < 8) {
        setState(() => _error = 'Use at least 8 characters.');
        return;
      }
      if (a != _b.text) {
        setState(() => _error = 'The two passwords do not match.');
        return;
      }
    } else if (a.isEmpty) {
      setState(() => _error = 'Enter the password.');
      return;
    }
    Navigator.of(context).pop(a);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message, style: kSubtle),
            const SizedBox(height: 14),
            TextField(
              controller: _a,
              autofocus: true,
              obscureText: !_show,
              decoration: fieldDec('Password').copyWith(
                suffixIcon: IconButton(
                  tooltip: _show ? 'Hide' : 'Show',
                  icon: Icon(
                    _show ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: widget.confirm ? null : (_) => _ok(),
            ),
            if (widget.confirm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _b,
                obscureText: !_show,
                decoration: fieldDec('Repeat password'),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _ok(),
              ),
            ],
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
          onPressed: _ok,
          child: Text(widget.confirm ? 'Create backup' : 'Restore'),
        ),
      ],
    );
  }
}
