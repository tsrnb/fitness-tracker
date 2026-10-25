import 'package:shared_preferences/shared_preferences.dart';
import '../storage.dart' show UserRow, FoodRow;
import 'api_client.dart';

/// Cloud-backed store with the same public API the app used against SQLite,
/// so [AppController] barely changes: profiles, per-profile key/value blobs and
/// the food library all live behind the API. Only `meta` (which profile is
/// active on this device) stays local.
class Backend {
  Backend._();
  static final Backend instance = Backend._();

  final _api = ApiClient.instance;
  final _chains = <String, Future<void>>{};

  Future<void> init() async {}

  Future<List<UserRow>> listUsers() async {
    final res = await _api.get('/profiles');
    return (res['profiles'] as List).map((p) => UserRow(p['id'] as int, p['name'] as String)).toList();
  }

  Future<int> addUser(String name) async => (await _api.post('/profiles', {'name': name}))['id'] as int;

  Future<void> renameUser(int id, String name) => _api.patch('/profiles/$id', {'name': name});

  Future<void> deleteUser(int id) async {
    await _api.delete('/profiles/$id');
    if (await getMeta('activeUser') == id.toString()) await clearMeta('activeUser');
  }

  Future<String?> getMeta(String k) async => (await SharedPreferences.getInstance()).getString('meta.$k');
  Future<void> setMeta(String k, String v) async => (await SharedPreferences.getInstance()).setString('meta.$k', v);
  Future<void> clearMeta(String k) async => (await SharedPreferences.getInstance()).remove('meta.$k');

  Future<Map<String, dynamic>> getUserData(int uid) async {
    final res = await _api.get('/profiles/$uid/data');
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  /// Writes to the same key are sent one after another so an older edit can
  /// never land after a newer one.
  Future<void> setUserKV(int uid, String k, dynamic v) {
    final id = '$uid/$k';
    final prev = _chains[id] ?? Future.value();
    final next = prev.catchError((_) {}).then((_) => _api.put('/profiles/$uid/data/$k', {'value': v})).then((_) {});
    _chains[id] = next;
    return next;
  }

  Future<List<FoodRow>> getFoods(int uid) async {
    final res = await _api.get('/profiles/$uid/foods');
    return (res['foods'] as List)
        .map((r) => FoodRow(r['id'] as int, r['name'] as String, (r['kcal'] as num).toDouble(), (r['protein'] as num).toDouble(),
            (r['carb'] as num).toDouble(), (r['fat'] as num).toDouble(), (r['fiber'] as num).toDouble()))
        .toList();
  }

  Map<String, dynamic> _food(String name, double kcal, double protein, double carb, double fat, double fiber) =>
      {'name': name, 'kcal': kcal, 'protein': protein, 'carb': carb, 'fat': fat, 'fiber': fiber};

  Future<void> addFood(int uid, String name, double kcal, double protein, [double carb = 0, double fat = 0, double fiber = 0]) =>
      _api.post('/profiles/$uid/foods', _food(name, kcal, protein, carb, fat, fiber));

  Future<void> updateFood(int uid, int id, String name, double kcal, double protein, double carb, double fat, double fiber) =>
      _api.put('/profiles/$uid/foods/$id', _food(name, kcal, protein, carb, fat, fiber));

  Future<void> deleteFood(int uid, int id) => _api.delete('/profiles/$uid/foods/$id');

  /// Moves one on-device profile into the account. Returns its new cloud id.
  Future<int> importProfile({required int localId, required String name, required Map<String, dynamic> data, required List<FoodRow> foods}) async {
    final res = await _api.post('/import', {
      'profiles': [
        {
          'localId': localId,
          'name': name,
          'data': data,
          'foods': foods.map((f) => _food(f.name, f.kcal, f.protein, f.carb, f.fat, f.fiber)).toList(),
        }
      ]
    });
    return (res['profiles'] as List).first['id'] as int;
  }

  Future<void> deleteAccount() => _api.delete('/account');
}
