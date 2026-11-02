import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../db.dart';
import '../state.dart';
import '../theme.dart';
import '../updater.dart';
import 'backup_panel.dart';
import 'common.dart';
import 'holidays_panel.dart';
import 'security_panel.dart';
import 'settings_forms.dart';

enum _Stage { idle, checking, upToDate, available, installing, error }

/// Company, work rules, software update, contact and about.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsFormController _c = SettingsFormController(widget.state);
  final _form = GlobalKey<FormState>();

  String _version = '1.0.0';
  _Stage _stage = _Stage.idle;
  UpdateInfo? _info;
  double _progress = 0;
  String _error = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) {
      showMsg(context, 'Please fix the highlighted fields.');
      return;
    }
    await widget.state.saveSettings(_c.toMap());
    if (!mounted) return;
    showMsg(context, 'Settings saved.');
  }

  String _friendly(Object e) {
    if (e is UpdateException) return e.message;
    return 'Could not reach the update server. '
        'Please check your internet connection and try again.';
  }

  Future<void> _check() async {
    setState(() => _stage = _Stage.checking);
    try {
      final info = await Updater.check(_version);
      if (!mounted) return;
      setState(() {
        _info = info;
        _stage = info == null ? _Stage.upToDate : _Stage.available;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendly(e);
        _stage = _Stage.error;
      });
    }
  }

  Future<void> _install() async {
    final info = _info;
    if (info == null) return;
    setState(() {
      _stage = _Stage.installing;
      _progress = 0;
    });
    try {
      await Updater.install(
        info,
        onProgress: (f) {
          if (mounted) setState(() => _progress = f);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendly(e);
        _stage = _Stage.error;
      });
    }
  }

  Future<void> _mail() async {
    final uri = Uri.parse('mailto:$kSupportEmail?subject=Muster%20support');
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      showMsg(context, 'No email app found. Write to $kSupportEmail instead.');
    }
  }

  Future<void> _copyMail() async {
    await Clipboard.setData(const ClipboardData(text: kSupportEmail));
    if (!mounted) return;
    showMsg(context, 'Email address copied.');
  }

  Future<void> _openFolder() async {
    try {
      await Process.start('explorer', [AppPaths.root]);
    } catch (_) {
      if (!mounted) return;
      showMsg(context, 'Could not open the folder.');
    }
  }

  Widget _updateBody() {
    switch (_stage) {
      case _Stage.idle:
        return const Text(
          'Muster downloads updates only over HTTPS and installs them only '
          'after checking the digital signature. Your data is never touched.',
          style: kSubtle,
        );
      case _Stage.checking:
        return const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Checking for updates…'),
          ],
        );
      case _Stage.upToDate:
        return const Row(
          children: [
            Icon(Icons.check_circle, color: kGreen, size: 18),
            SizedBox(width: 8),
            Text('You are using the latest version.'),
          ],
        );
      case _Stage.available:
        final info = _info;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${info?.version ?? ''} is available.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (info != null && info.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 140),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kMica,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  child: Text(info.notes, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _install,
              icon: const Icon(Icons.system_update_alt, size: 18),
              label: const Text('Download and install'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Muster will close and reopen by itself after the update.',
              style: kSubtle,
            ),
          ],
        );
      case _Stage.installing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _progress >= 1
                  ? 'Verifying and installing…'
                  : 'Downloading… ${(_progress * 100).toStringAsFixed(0)}%',
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          ],
        );
      case _Stage.error:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: kRed, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(_error, style: const TextStyle(color: kRed))),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _stage == _Stage.checking || _stage == _Stage.installing;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings', style: kTitle),
              const SizedBox(height: 16),
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PanelTitle('Company'),
                          CompanyFields(c: _c),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PanelTitle(
                            'Work rules',
                            subtitle:
                                'Default for all workers. A worker with own '
                                'timing keeps that timing.',
                          ),
                          WorkRulesFields(c: _c),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Save changes'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              HolidaysPanel(state: widget.state),
              const SizedBox(height: 16),
              SecurityPanel(state: widget.state),
              const SizedBox(height: 16),
              BackupPanel(state: widget.state),
              const SizedBox(height: 16),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: PanelTitle(
                            'Software update',
                            subtitle: 'Installed version',
                          ),
                        ),
                        Text('v$_version', style: kSubtle),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: busy ? null : _check,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Check for updates'),
                        ),
                      ],
                    ),
                    _updateBody(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PanelTitle(
                      'Contact us',
                      subtitle: 'Questions, problems or ideas? Write to us.',
                    ),
                    Row(
                      children: [
                        const Icon(Icons.mail_outline, size: 18, color: kNavy),
                        const SizedBox(width: 8),
                        const SelectableText(
                          kSupportEmail,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: _copyMail,
                          child: const Text('Copy'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _mail,
                          child: const Text('Send email'),
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
                    const PanelTitle('About'),
                    Text('$kAppName v$_version', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text(
                      'Free, offline attendance and salary software. '
                      'All data stays on this computer.',
                      style: kSubtle,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            AppPaths.root,
                            style: kSubtle,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _openFolder,
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Open data folder'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
