import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Browser-storage-backed store — `sqflite` has no web implementation at
/// all, so this mirrors [Backend]'s native (storage_io.dart) public API
/// exactly, backed by `shared_preferences` (plain `window.localStorage` on
/// web) instead of a real SQLite file. No caller in lib/features/** needs to
/// know which backend is active; `storage.dart` picks this file on web via
/// a conditional export.
class Backend {
  Backend._();
  static final Backend instance = Backend._();
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sp async => _prefs ??= await SharedPreferences.getInstance();

  Future<void> init() async {
    await _sp;
  }

  List<Map<String, dynamic>> _readUsers(SharedPreferences sp) {
    final raw = sp.getString('users');
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  Future<void> _writeUsers(SharedPreferences sp, List<Map<String, dynamic>> users) async {
    await sp.setString('users', jsonEncode(users));
  }

  Future<List<UserRow>> listUsers() async {
    final sp = await _sp;
    return _readUsers(sp).map((u) => UserRow(u['id'] as int, u['name'] as String)).toList();
  }

  Future<int> addUser(String name) async {
    final sp = await _sp;
    final users = _readUsers(sp);
    final nextId = sp.getInt('nextUserId') ?? 1;
    users.add({'id': nextId, 'name': name, 'created': DateTime.now().toIso8601String()});
    await _writeUsers(sp, users);
    await sp.setInt('nextUserId', nextId + 1);
    return nextId;
  }

  Future<void> renameUser(int id, String name) async {
    final sp = await _sp;
    final users = _readUsers(sp);
    final idx = users.indexWhere((u) => u['id'] == id);
    if (idx == -1) return;
    users[idx] = {...users[idx], 'name': name};
    await _writeUsers(sp, users);
  }

  /// Mirrors [storage_io.dart]'s deleteUser: drops the user row, every
  /// `kv:$id:*` key (settings, diet, history, plan, ...), the food library,
  /// and clears `meta:activeUser` if it pointed at this id.
  Future<void> deleteUser(int id) async {
    final sp = await _sp;
    final users = _readUsers(sp)..removeWhere((u) => u['id'] == id);
    await _writeUsers(sp, users);
    final kvPrefix = 'kv:$id:';
    for (final key in sp.getKeys().where((k) => k.startsWith(kvPrefix)).toList()) {
      await sp.remove(key);
    }
    await sp.remove('foods:$id');
    if (sp.getString('meta:activeUser') == id.toString()) {
      await sp.remove('meta:activeUser');
    }
  }

  Future<String?> getMeta(String k) async {
    final sp = await _sp;
    return sp.getString('meta:$k');
  }

  Future<void> setMeta(String k, String v) async {
    final sp = await _sp;
    await sp.setString('meta:$k', v);
  }

  Future<Map<String, dynamic>> getUserData(int uid) async {
    final sp = await _sp;
    final prefix = 'kv:$uid:';
    final out = <String, dynamic>{};
    for (final key in sp.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final raw = sp.getString(key);
      if (raw == null) continue;
      final k = key.substring(prefix.length);
      try {
        out[k] = jsonDecode(raw);
      } catch (_) {
        out[k] = raw;
      }
    }
    return out;
  }

  Future<void> setUserKV(int uid, String k, dynamic v) async {
    final sp = await _sp;
    await sp.setString('kv:$uid:$k', jsonEncode(v));
  }

  List<Map<String, dynamic>> _readFoods(SharedPreferences sp, int uid) {
    final raw = sp.getString('foods:$uid');
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  Future<List<FoodRow>> getFoods(int uid) async {
    final sp = await _sp;
    final foods = _readFoods(sp, uid)..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    return foods
        .map((f) => FoodRow(
              f['id'] as int,
              f['name'] as String,
              (f['kcal'] as num).toDouble(),
              (f['protein'] as num).toDouble(),
              (f['carb'] as num?)?.toDouble() ?? 0,
              (f['fat'] as num?)?.toDouble() ?? 0,
              (f['fiber'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }

  Future<void> addFood(int uid, String name, double kcal, double protein, [double carb = 0, double fat = 0, double fiber = 0]) async {
    final sp = await _sp;
    final foods = _readFoods(sp, uid);
    final nextId = sp.getInt('nextFoodId') ?? 1;
    foods.add({'id': nextId, 'name': name, 'kcal': kcal, 'protein': protein, 'carb': carb, 'fat': fat, 'fiber': fiber});
    await sp.setString('foods:$uid', jsonEncode(foods));
    await sp.setInt('nextFoodId', nextId + 1);
  }

  // updateFood/deleteFood take only an id (not uid) in the shared public API
  // (matches storage_io.dart, where sqlite's foods table has globally unique
  // ids) — scan every user's food list for the matching id.
  Future<void> updateFood(int id, String name, double kcal, double protein, double carb, double fat, double fiber) async {
    final sp = await _sp;
    for (final key in sp.getKeys()) {
      if (!key.startsWith('foods:')) continue;
      final uid = int.parse(key.substring('foods:'.length));
      final foods = _readFoods(sp, uid);
      final idx = foods.indexWhere((f) => f['id'] == id);
      if (idx == -1) continue;
      foods[idx] = {...foods[idx], 'name': name, 'kcal': kcal, 'protein': protein, 'carb': carb, 'fat': fat, 'fiber': fiber};
      await sp.setString(key, jsonEncode(foods));
      return;
    }
  }

  Future<void> deleteFood(int id) async {
    final sp = await _sp;
    for (final key in sp.getKeys()) {
      if (!key.startsWith('foods:')) continue;
      final uid = int.parse(key.substring('foods:'.length));
      final foods = _readFoods(sp, uid);
      final next = foods.where((f) => f['id'] != id).toList();
      if (next.length == foods.length) continue;
      await sp.setString(key, jsonEncode(next));
      return;
    }
  }

  Future<String> get dbPath async => 'browser-local-storage';
}
