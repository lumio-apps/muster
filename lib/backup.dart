import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'backup_crypto.dart';
import 'db.dart';

export 'backup_crypto.dart' show BackupException;

/// Creates and restores password-protected backups (.mbk files).
/// A backup holds the database and all worker photos.
class BackupService {
  static const int currentDbVersion = 2;

  /// Writes an encrypted backup to [destPath]. Returns the file size.
  static Future<int> create({
    required AppDb db,
    required String password,
    required String destPath,
    required String appVersion,
  }) async {
    final tmp = await Directory.systemTemp.createTemp('muster_backup_');
    try {
      final snapshot = p.join(tmp.path, 'muster.db');
      await db.snapshotTo(snapshot);

      final archive = Archive();
      final dbBytes = await File(snapshot).readAsBytes();
      archive.addFile(ArchiveFile('muster.db', dbBytes.length, dbBytes));

      final photos = Directory(AppPaths.photosDir);
      if (photos.existsSync()) {
        for (final e in photos.listSync()) {
          if (e is File) {
            final bytes = await e.readAsBytes();
            final name = 'photos/${p.basename(e.path)}';
            archive.addFile(ArchiveFile(name, bytes.length, bytes));
          }
        }
      }

      final meta = utf8.encode(
        jsonEncode({
          'app': 'Muster',
          'app_version': appVersion,
          'db_version': currentDbVersion,
          'created': DateTime.now().toIso8601String(),
        }),
      );
      archive.addFile(ArchiveFile('meta.json', meta.length, meta));

      final zipped = ZipEncoder().encode(archive);
      if (zipped == null) {
        throw BackupException('Could not pack the backup.');
      }
      final plain = Uint8List.fromList(zipped);
      final encrypted = await Isolate.run(() => encryptBytes(plain, password));
      await File(destPath).writeAsBytes(encrypted, flush: true);
      return encrypted.length;
    } finally {
      _cleanup(tmp);
    }
  }

  /// Replaces all current data with the backup, then restarts Muster.
  /// Current data is first moved to AppData\Muster\restore-backups, so
  /// nothing is ever lost.
  static Future<void> restore({
    required AppDb db,
    required String backupPath,
    required String password,
  }) async {
    final bytes = await File(backupPath).readAsBytes();
    if (!looksLikeBackup(bytes)) {
      throw BackupException('This is not a Muster backup file.');
    }
    final plain = await Isolate.run(() => decryptBytes(bytes, password));
    if (plain == null) {
      throw BackupException('Wrong password, or the backup file is damaged.');
    }

    final tmp = await Directory.systemTemp.createTemp('muster_restore_');
    final newDb = p.join(tmp.path, 'muster.db');
    final newPhotos = p.join(tmp.path, 'photos');

    try {
      final archive = ZipDecoder().decodeBytes(plain);
      var hasDb = false;
      for (final f in archive) {
        if (!f.isFile) continue;
        final name = f.name.replaceAll('\\', '/');
        final data = f.content as List<int>;
        if (name == 'muster.db') {
          hasDb = true;
          await File(newDb).writeAsBytes(data);
        } else if (name.startsWith('photos/')) {
          final parts = name.split('/');
          if (parts.length == 2 && parts[1].isNotEmpty && parts[1] != '..') {
            Directory(newPhotos).createSync(recursive: true);
            await File(p.join(newPhotos, parts[1])).writeAsBytes(data);
          }
        }
      }
      if (!hasDb) {
        throw BackupException('The backup does not contain any data.');
      }
      await _validate(newDb);
    } catch (_) {
      _cleanup(tmp);
      rethrow;
    }

    // Point of no return: close the database and swap the files.
    await db.close();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final safety = Directory(p.join(AppPaths.root, 'restore-backups', stamp));
    safety.createSync(recursive: true);

    try {
      File(AppPaths.dbFile).renameSync(p.join(safety.path, 'muster.db'));
      final current = Directory(AppPaths.photosDir);
      if (current.existsSync()) {
        current.renameSync(p.join(safety.path, 'photos'));
      }
      File(newDb).copySync(AppPaths.dbFile);
      Directory(AppPaths.photosDir).createSync(recursive: true);
      final src = Directory(newPhotos);
      if (src.existsSync()) {
        for (final e in src.listSync()) {
          if (e is File) {
            e.copySync(p.join(AppPaths.photosDir, p.basename(e.path)));
          }
        }
      }
    } catch (_) {
      _rollback(safety);
      await _relaunch();
    }

    _cleanup(tmp);
    await _relaunch();
  }

  static Future<void> _validate(String path) async {
    Database? db;
    try {
      db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      final version = await db.getVersion();
      if (version > currentDbVersion) {
        throw BackupException(
          'This backup was made by a newer Muster. Please update Muster first.',
        );
      }
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name IN ('settings', 'workers', 'attendance')",
      );
      if (rows.length != 3) {
        throw BackupException('The backup data is not valid.');
      }
    } on BackupException {
      rethrow;
    } catch (_) {
      throw BackupException('The backup data is not valid.');
    } finally {
      await db?.close();
    }
  }

  static void _rollback(Directory safety) {
    try {
      final dbFile = File(AppPaths.dbFile);
      if (dbFile.existsSync()) dbFile.deleteSync();
      final photos = Directory(AppPaths.photosDir);
      if (photos.existsSync()) photos.deleteSync(recursive: true);
      final oldDb = File(p.join(safety.path, 'muster.db'));
      if (oldDb.existsSync()) oldDb.renameSync(AppPaths.dbFile);
      final oldPhotos = Directory(p.join(safety.path, 'photos'));
      if (oldPhotos.existsSync()) oldPhotos.renameSync(AppPaths.photosDir);
    } catch (_) {
      // Nothing more can be done here; the safety folder still has the data.
    }
  }

  static void _cleanup(Directory dir) {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {
      // Temporary files can be left behind safely.
    }
  }

  static Future<void> _relaunch() async {
    await Process.start(
      Platform.resolvedExecutable,
      const <String>[],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }
}
