import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class UserRow {
  final int id;
  final String name;
  const UserRow(this.id, this.name);
}

class FoodRow {
  final int id;
  final String name;
  final double kcal;
  final double protein;
  final double carb;
  final double fat;
  final double fiber;
  const FoodRow(this.id, this.name, this.kcal, this.protein, [this.carb = 0, this.fat = 0, this.fiber = 0]);
}

/// SQLite-backed store (Android/iOS/desktop) mirroring the React app's
/// sql.js schema: users(id,name,created) · kv(uid,k,v) ·
/// foods(id,uid,name,kcal,protein,carb,fat,fiber) · meta(k,v)
class Backend {
  Backend._();
  static final Backend instance = Backend._();
  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'cuttracker.db');
    _db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, created TEXT)');
        await db.execute('CREATE TABLE kv(uid INTEGER, k TEXT, v TEXT, PRIMARY KEY(uid,k))');
        await db.execute('CREATE TABLE foods(id INTEGER PRIMARY KEY AUTOINCREMENT, uid INTEGER, name TEXT, kcal REAL, protein REAL, carb REAL, fat REAL, fiber REAL)');
        await db.execute('CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE foods ADD COLUMN carb REAL DEFAULT 0');
          await db.execute('ALTER TABLE foods ADD COLUMN fat REAL DEFAULT 0');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE foods ADD COLUMN fiber REAL DEFAULT 0');
        }
      },
    );
    return _db!;
  }

  Future<void> init() async {
    await _database;
  }

  Future<List<UserRow>> listUsers() async {
    final db = await _database;
    final rows = await db.query('users', orderBy: 'id');
    return rows.map((r) => UserRow(r['id'] as int, r['name'] as String)).toList();
  }

  Future<int> addUser(String name) async {
    final db = await _database;
    return db.insert('users', {'name': name, 'created': DateTime.now().toIso8601String()});
  }

  Future<void> renameUser(int id, String name) async {
    final db = await _database;
    await db.update('users', {'name': name}, where: 'id=?', whereArgs: [id]);
  }

  Future<String?> getMeta(String k) async {
    final db = await _database;
    final rows = await db.query('meta', where: 'k=?', whereArgs: [k], limit: 1);
    return rows.isEmpty ? null : rows.first['v'] as String?;
  }

  Future<void> setMeta(String k, String v) async {
    final db = await _database;
    await db.insert('meta', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>> getUserData(int uid) async {
    final db = await _database;
    final rows = await db.query('kv', where: 'uid=?', whereArgs: [uid]);
    final out = <String, dynamic>{};
    for (final r in rows) {
      final k = r['k'] as String;
      final v = r['v'] as String;
      try {
        out[k] = jsonDecode(v);
      } catch (_) {
        out[k] = v;
      }
    }
    return out;
  }

  Future<void> setUserKV(int uid, String k, dynamic v) async {
    final db = await _database;
    final json = jsonEncode(v);
    await db.insert('kv', {'uid': uid, 'k': k, 'v': json}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<FoodRow>> getFoods(int uid) async {
    final db = await _database;
    final rows = await db.query('foods', where: 'uid=?', whereArgs: [uid], orderBy: 'id DESC');
    return rows
        .map((r) => FoodRow(
              r['id'] as int,
              r['name'] as String,
              (r['kcal'] as num).toDouble(),
              (r['protein'] as num).toDouble(),
              (r['carb'] as num?)?.toDouble() ?? 0,
              (r['fat'] as num?)?.toDouble() ?? 0,
              (r['fiber'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }

  Future<void> addFood(int uid, String name, double kcal, double protein, [double carb = 0, double fat = 0, double fiber = 0]) async {
    final db = await _database;
    await db.insert('foods', {'uid': uid, 'name': name, 'kcal': kcal, 'protein': protein, 'carb': carb, 'fat': fat, 'fiber': fiber});
  }

  Future<void> updateFood(int id, String name, double kcal, double protein, double carb, double fat, double fiber) async {
    final db = await _database;
    await db.update('foods', {'name': name, 'kcal': kcal, 'protein': protein, 'carb': carb, 'fat': fat, 'fiber': fiber}, where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteFood(int id) async {
    final db = await _database;
    await db.delete('foods', where: 'id=?', whereArgs: [id]);
  }

  Future<String> get dbPath async {
    final db = await _database;
    return db.path;
  }
}
