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
        version: 2,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _create(db, version);
          await _createMoney(db);
        },
        // Upgrades only add tables. Existing data is never touched.
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createMoney(db);
          }
        },
      ),
    );
    final appDb = AppDb._(db);
    await appDb._normalizePhotos();
    return appDb;
  }

  /// Worker photo paths are stored as full paths. After a backup is restored
  /// on another computer or user account the folder is different, so point
  /// each path at the photos folder of this computer.
  Future<void> _normalizePhotos() async {
    try {
      final rows = await _db.query(
        'workers',
        columns: ['id', 'photo_path'],
        where: "photo_path IS NOT NULL AND photo_path != ''",
      );
      for (final r in rows) {
        final old = r['photo_path'] as String;
        final fixed = p.join(AppPaths.photosDir, p.basename(old));
        if (fixed != old && File(fixed).existsSync()) {
          await _db.update(
            'workers',
            {'photo_path': fixed},
            where: 'id = ?',
            whereArgs: [r['id']],
          );
        }
      }
    } catch (_) {
      // A photo problem must never stop the app from opening.
    }
  }

  /// Writes a consistent copy of the whole database to [path].
  Future<void> snapshotTo(String path) async {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
    final escaped = path.replaceAll("'", "''");
    await _db.execute("VACUUM INTO '$escaped'");
  }

  Future<void> close() => _db.close();

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

  /// Added in database version 2: advances and paid salaries.
  static Future<void> _createMoney(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS advances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        worker_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (worker_id) REFERENCES workers (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS salary_runs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        worker_id INTEGER NOT NULL,
        month TEXT NOT NULL,
        gross REAL NOT NULL,
        advance_deducted REAL NOT NULL DEFAULT 0,
        paid_on TEXT NOT NULL,
        UNIQUE (worker_id, month),
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

  // ---- advances and paid salaries ----

  Future<List<Advance>> advances() async {
    final rows = await _db.query('advances', orderBy: 'date DESC, id DESC');
    return rows.map(Advance.fromMap).toList();
  }

  Future<int> insertAdvance(Advance a) => _db.insert('advances', a.toMap());

  Future<void> deleteAdvance(int id) async {
    await _db.delete('advances', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SalaryRun>> salaryRuns() async {
    final rows = await _db.query('salary_runs');
    return rows.map(SalaryRun.fromMap).toList();
  }

  Future<void> saveSalaryRun(SalaryRun r) async {
    await _db.insert(
      'salary_runs',
      r.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSalaryRun(int workerId, String month) async {
    await _db.delete(
      'salary_runs',
      where: 'worker_id = ? AND month = ?',
      whereArgs: [workerId, month],
    );
  }

  /// All attendance records from [from] to [to] (both "yyyy-MM-dd").
  Future<List<Attendance>> attendanceBetween(String from, String to) async {
    final rows = await _db.query(
      'attendance',
      where: 'date >= ? AND date <= ?',
      whereArgs: [from, to],
    );
    return rows.map(Attendance.fromMap).toList();
  }
}
