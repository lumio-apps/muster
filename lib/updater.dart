import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'config.dart';

class UpdateException implements Exception {
  UpdateException(this.message);
  final String message;

  @override
  String toString() => message;
}

class UpdateInfo {
  UpdateInfo({
    required this.version,
    required this.notes,
    required this.zipUrl,
    required this.sigUrl,
  });

  final String version;
  final String notes;
  final String zipUrl;
  final String sigUrl;
}

/// Safe in-app updater.
///
/// An update is installed only if:
///  * every download link is HTTPS and on a GitHub host, and
///  * the zip's Ed25519 signature matches [kUpdatePublicKey].
/// User data lives in %APPDATA%\Muster and is never touched by an update.
class Updater {
  static const String _placeholderKey = 'REPLACE_WITH_PUBLIC_KEY';
  static const int _maxZipBytes = 400 * 1024 * 1024;

  static List<int> _parts(String v) {
    final clean = v.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    return clean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  static bool isNewer(String remote, String local) {
    final r = _parts(remote);
    final l = _parts(local);
    for (var i = 0; i < 3; i++) {
      final a = i < r.length ? r[i] : 0;
      final b = i < l.length ? l[i] : 0;
      if (a != b) return a > b;
    }
    return false;
  }

  static bool _hostAllowed(Uri uri) {
    if (uri.scheme != 'https') return false;
    final h = uri.host.toLowerCase();
    return h == 'github.com' ||
        h == 'api.github.com' ||
        h.endsWith('.github.com') ||
        h.endsWith('.githubusercontent.com');
  }

  /// Returns the newest release if it is newer than [currentVersion].
  static Future<UpdateInfo?> check(String currentVersion) async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$kGithubOwner/$kGithubRepo/releases/latest',
    );
    final res = await http.get(uri, headers: {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'Muster-Updater',
    }).timeout(const Duration(seconds: 20));

    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw UpdateException(
        'Update server replied with HTTP ${res.statusCode}. Try again later.',
      );
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String? ?? '').trim();
    if (tag.isEmpty || !isNewer(tag, currentVersion)) return null;

    String? zipUrl;
    String? sigUrl;
    final assets = (json['assets'] as List<dynamic>? ?? []);
    for (final a in assets) {
      final m = a as Map<String, dynamic>;
      final name = (m['name'] as String? ?? '').toLowerCase();
      final url = m['browser_download_url'] as String? ?? '';
      if (name.endsWith('-windows.zip')) zipUrl = url;
      if (name.endsWith('-windows.zip.sig')) sigUrl = url;
    }
    if (zipUrl == null || sigUrl == null) {
      throw UpdateException(
        'The newest release has no signed Windows package, so it was ignored.',
      );
    }

    return UpdateInfo(
      version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
      notes: (json['body'] as String? ?? '').trim(),
      zipUrl: zipUrl,
      sigUrl: sigUrl,
    );
  }

  static Future<Uint8List> _download(
    String url, {
    void Function(double)? onProgress,
  }) async {
    final uri = Uri.parse(url);
    if (!_hostAllowed(uri)) {
      throw UpdateException('Blocked: the update link is not a safe HTTPS link.');
    }
    final client = http.Client();
    try {
      final req = http.Request('GET', uri);
      req.headers['User-Agent'] = 'Muster-Updater';
      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw UpdateException('Download failed (HTTP ${res.statusCode}).');
      }
      final finalUrl = res.request?.url;
      if (finalUrl != null && finalUrl.scheme != 'https') {
        throw UpdateException('Blocked: download was redirected to a non-HTTPS link.');
      }
      final total = res.contentLength ?? 0;
      if (total > _maxZipBytes) {
        throw UpdateException('Update file is unexpectedly large.');
      }
      final builder = BytesBuilder(copy: false);
      var got = 0;
      await for (final chunk in res.stream) {
        builder.add(chunk);
        got += chunk.length;
        if (got > _maxZipBytes) {
          throw UpdateException('Update file is unexpectedly large.');
        }
        if (total > 0) onProgress?.call(got / total);
      }
      return builder.takeBytes();
    } finally {
      client.close();
    }
  }

  static Future<bool> _verify(Uint8List data, String sigBase64) async {
    if (kUpdatePublicKey == _placeholderKey) {
      throw UpdateException(
        'This build has no update signing key, so updates cannot be verified.',
      );
    }
    try {
      final pub = base64Decode(kUpdatePublicKey.trim());
      final sig = base64Decode(sigBase64.trim());
      return await Ed25519().verify(
        data,
        signature: Signature(
          sig,
          publicKey: SimplePublicKey(pub, type: KeyPairType.ed25519),
        ),
      );
    } on FormatException {
      throw UpdateException('The update signature is not valid.');
    }
  }

  /// Downloads, verifies and installs the update, then restarts Muster.
  /// Only returns by throwing; on success the process exits.
  static Future<void> install(
    UpdateInfo info, {
    void Function(double)? onProgress,
  }) async {
    if (!Platform.isWindows) {
      throw UpdateException('In-app updates work on Windows only.');
    }

    final sigBytes = await _download(info.sigUrl);
    final zip = await _download(info.zipUrl, onProgress: onProgress);

    final ok = await _verify(zip, utf8.decode(sigBytes));
    if (!ok) {
      throw UpdateException(
        'The update failed signature verification and was NOT installed.',
      );
    }

    final work = Directory(p.join(Directory.systemTemp.path, 'muster_update'));
    if (work.existsSync()) work.deleteSync(recursive: true);
    final stage = Directory(p.join(work.path, 'files'));
    stage.createSync(recursive: true);

    final archive = ZipDecoder().decodeBytes(zip);
    for (final f in archive) {
      final name = f.name.replaceAll('\\', '/');
      final target = p.normalize(p.join(stage.path, name));
      if (!p.isWithin(stage.path, target)) {
        throw UpdateException('The update archive contains an unsafe path.');
      }
      if (f.isFile) {
        final file = File(target);
        file.createSync(recursive: true);
        file.writeAsBytesSync(f.content as List<int>);
      } else {
        Directory(target).createSync(recursive: true);
      }
    }

    final exeName = p.basename(Platform.resolvedExecutable);
    if (!File(p.join(stage.path, exeName)).existsSync()) {
      throw UpdateException('The update package is missing $exeName.');
    }

    final appDir = File(Platform.resolvedExecutable).parent.path;
    final bat = File(p.join(work.path, 'apply_update.bat'));
    bat.writeAsStringSync([
      '@echo off',
      'ping 127.0.0.1 -n 4 >nul',
      'robocopy "${stage.path}" "$appDir" /E /IS /IT /R:10 /W:1 >nul',
      'start "" "${p.join(appDir, exeName)}"',
      'exit /b 0',
    ].join('\r\n'));

    await Process.start(
      'cmd',
      ['/c', bat.path],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }
}
