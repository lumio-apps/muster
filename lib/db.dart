import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'models.dart';

/// Where Muster keeps its data on this computer.
class AppPaths {
  static String get root {
    final appData = Platform.environment['APPDATA'] ?? Directory.current.path;
    return p.join(appData, 'Muster');
  }

  static String get dbFile => p.join(root, 'muster.db');
  static String get photosDir => p.join(root, 'photos');
}

class AppDb {
  AppDb._(this._db);

  final Database _db;

  static Future<AppDb> open() async {
    sqfliteFfiInit();
    await Directory(AppPaths.root).create(recursive: true);
    await Directory(AppPaths.photosDir).create(recursive: true);
    final db = await databaseFactoryFfi.openDatabase(
      AppPaths.dbFile,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _create,
      ),
    );
    return AppDb._(db);
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute(
      'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    await db.execute('''
      CREATE TABLE workers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        joined_on TEXT NOT NULL,
        pay_type TEXT NOT NULL,
        rate REAL NOT NULL DEFAULT 0,
        ot_multiplier REAL NOT NULL DEFAULT 1.5,
        use_company_timing INTEGER NOT NULL DEFAULT 1,
        shift_start TEXT NOT NULL DEFAULT '08:00',
        shift_end TEXT NOT NULL DEFAULT '17:00',
        break_minutes INTEGER NOT NULL DEFAULT 60,
        late_grace INTEGER NOT NULL DEFAULT 10,
        weekly_off TEXT NOT NULL DEFAULT '7',
        photo_path TEXT,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        worker_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        check_in TEXT,
        check_out TEXT,
        ot_hours REAL NOT NULL DEFAULT 0,
        UNIQUE (worker_id, date),
        FOREIGN KEY (worker_id) REFERENCES workers (id) ON DELETE CASCADE
      )
    ''');
  }

  // ---- settings ----

  Future<Map<String, String>> allSettings() async {
    final rows = await _db.query('settings');
    return {
      for (final r in rows) r['key'] as String: r['value'] as String,
    };
  }

  Future<void> setSetting(String key, String value) async {
    await _db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---- workers ----

  Future<List<Worker>> workers() async {
    final rows = await _db.query('workers', orderBy: 'name COLLATE NOCASE');
    return rows.map(Worker.fromMap).toList();
  }

  Future<int> insertWorker(Worker w) => _db.insert('workers', w.toMap());

  Future<void> updateWorker(Worker w) async {
    await _db.update('workers', w.toMap(), where: 'id = ?', whereArgs: [w.id]);
  }

  // ---- attendance ----

  Future<Map<int, Attendance>> attendanceOn(String date) async {
    final rows =
        await _db.query('attendance', where: 'date = ?', whereArgs: [date]);
    final list = rows.map(Attendance.fromMap);
    return {for (final a in list) a.workerId: a};
  }

  Future<void> saveAttendance(Attendance a) async {
    await _db.insert(
      'attendance',
      a.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAttendance(int workerId, String date) async {
    await _db.delete(
      'attendance',
      where: 'worker_id = ? AND date = ?',
      whereArgs: [workerId, date],
    );
  }
}
