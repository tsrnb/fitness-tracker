import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/lib/storage.dart';
import '../shared/lib/cloud/api_client.dart';
import '../features/account/presentation/auth_screens.dart' show RestoreScreen;
import '../shared/lib/health_service.dart';
import '../shared/lib/helpers.dart';
import '../shared/theme.dart';
import '../features/calibration/domain/calibration_engine.dart' show calibrationExpired;

/// Mirrors the React app's DEFAULT_DATA / AppContext shape.
/// Numeric settings that an older settings form could have persisted as text
/// (e.g. "150"); every reader casts them `as num?`, so coerce them here.
Map<String, dynamic> sanitizeSettings(Map<String, dynamic> s) {
  const numericKeys = [
    'proteinGoal', 'carbGoal', 'fatGoal', 'fiberGoal', 'calorieGoal', 'stepGoal',
    'calorieBuffer', 'age', 'height', 'currentWeight', 'targetWeight',
    'paceDeficitKcal', 'paceSurplusKcal',
  ];
  for (final k in numericKeys) {
    final v = s[k];
    if (v is String) {
      final n = num.tryParse(v.trim());
      if (n != null) {
        s[k] = n;
      } else {
        s.remove(k);
      }
    }
  }
  return s;
}

class AppData {
  final Map<String, dynamic> settings;
  final List<Map<String, dynamic>> weight; // [{date, weight}]
  final Map<String, dynamic> history; // exerciseName -> [{date, sets:[{weight,reps}]}]
  final Map<String, dynamic> sessions; // date -> {day, at}
  final Map<String, dynamic> diet; // date -> [{id,name,kcal,protein}]
  final Map<String, dynamic> water; // date -> int (units of 250ml)
  final Map<String, dynamic> activity; // date -> {steps,kcal,min}
  final List<dynamic> photos;
  final Map<String, dynamic>? plan;
  // foodName (lowercased) -> {kcal,protein,carb,fat,fiber} — standing facts
  // the user has told the Ask AI chat about a food (e.g. "yogurt is 101kcal,
  // 11g protein"), persisted per-user so they carry across chat sessions and
  // app restarts, unlike the rest of a chat's conversation context.
  final Map<String, dynamic> aiFoodMemory;
  // The single in-progress-or-most-recent 14-Day Calibration record, if any
  // has ever been started — {mode, status, startDate, endDate, baseline,
  // result?}. See lib/features/calibration/domain/calibration_engine.dart
  // for the full shape. Starting a new calibration overwrites this; there's
  // no history of past ones yet.
  final Map<String, dynamic>? calibration;
  // Muscle-gain feature state — {level, tracked, setupDate, goalGainKg, tape,
  // chats}; null until the first-run setup. See features/muscle/domain.
  final Map<String, dynamic>? muscle;

  const AppData({
    this.settings = const {},
    this.weight = const [],
    this.history = const {},
    this.sessions = const {},
    this.diet = const {},
    this.water = const {},
    this.activity = const {},
    this.photos = const [],
    this.plan,
    this.aiFoodMemory = const {},
    this.calibration,
    this.muscle,
  });

  static const empty = AppData();

  factory AppData.fromMap(Map<String, dynamic> m) => AppData(
        settings: sanitizeSettings(Map<String, dynamic>.from(m['settings'] ?? {})),
        weight: List<Map<String, dynamic>>.from((m['weight'] ?? []).map((e) => Map<String, dynamic>.from(e))),
        history: Map<String, dynamic>.from(m['history'] ?? {}),
        sessions: Map<String, dynamic>.from(m['sessions'] ?? {}),
        diet: Map<String, dynamic>.from(m['diet'] ?? {}),
        water: Map<String, dynamic>.from(m['water'] ?? {}),
        activity: Map<String, dynamic>.from(m['activity'] ?? {}),
        photos: List<dynamic>.from(m['photos'] ?? []),
        plan: m['plan'] != null ? Map<String, dynamic>.from(m['plan']) : null,
        aiFoodMemory: Map<String, dynamic>.from(m['aiFoodMemory'] ?? {}),
        calibration: m['calibration'] != null ? Map<String, dynamic>.from(m['calibration']) : null,
        muscle: m['muscle'] != null ? Map<String, dynamic>.from(m['muscle']) : null,
      );

  AppData copyWith({
    Map<String, dynamic>? settings,
    List<Map<String, dynamic>>? weight,
    Map<String, dynamic>? history,
    Map<String, dynamic>? sessions,
    Map<String, dynamic>? diet,
    Map<String, dynamic>? water,
    Map<String, dynamic>? activity,
    List<dynamic>? photos,
    Object? plan = _unset,
    Map<String, dynamic>? aiFoodMemory,
    Object? calibration = _unset,
    Object? muscle = _unset,
  }) {
    return AppData(
      settings: settings ?? this.settings,
      weight: weight ?? this.weight,
      history: history ?? this.history,
      sessions: sessions ?? this.sessions,
      diet: diet ?? this.diet,
      water: water ?? this.water,
      activity: activity ?? this.activity,
      photos: photos ?? this.photos,
      plan: identical(plan, _unset) ? this.plan : plan as Map<String, dynamic>?,
      aiFoodMemory: aiFoodMemory ?? this.aiFoodMemory,
      calibration: identical(calibration, _unset) ? this.calibration : calibration as Map<String, dynamic>?,
      muscle: identical(muscle, _unset) ? this.muscle : muscle as Map<String, dynamic>?,
    );
  }

  dynamic operator [](String key) {
    switch (key) {
      case 'settings':
        return settings;
      case 'weight':
        return weight;
      case 'history':
        return history;
      case 'sessions':
        return sessions;
      case 'diet':
        return diet;
      case 'water':
        return water;
      case 'activity':
        return activity;
      case 'photos':
        return photos;
      case 'plan':
        return plan;
      case 'aiFoodMemory':
        return aiFoodMemory;
      case 'calibration':
        return calibration;
      case 'muscle':
        return muscle;
    }
    return null;
  }
}

const _unset = Object();

/// Where the Apple Health / Health Connect sync currently stands — surfaced
/// on the home screen so "did it actually sync" is never a mystery.
enum HealthSyncStatus { idle, syncing, success, failed }

class SimpleUser {
  final int id;
  final String name;
  const SimpleUser(this.id, this.name);
}

class AppController extends StateNotifier<AppState> {
  AppController() : super(AppState.loading()) {
    _init();
  }

  /// `state` itself is protected (StateNotifier internals only) — this is
  /// the public way for call sites outside app_state.dart (e.g. meal_log.dart,
  /// which needs the day-boundary setting to default a date) to read current data.
  AppState get current => state;

  final _backend = Backend.instance;
  final _local = LocalBackend.instance;
  final _api = ApiClient.instance;
  Timer? _healthSyncTimer;

  /// One-line messages for a snackbar (a save that failed and was rolled back, etc.).
  final notice = ValueNotifier<String?>(null);

  static const _healthSyncInterval = Duration(minutes: 5);

  Future<void> _init() async {
    _api.onSessionLost = _sessionLost;
    await _local.init();
    final session = await _api.restore();
    if (session == SessionState.signedIn) {
      await _afterSignIn();
      return;
    }
    await _showGate(session);
  }

  /// Lands on the right sign-in screen: landing (nothing on this device),
  /// "we found your data" (profiles from before accounts), or "sign in again".
  Future<void> _showGate(SessionState session, {String? error}) async {
    final localUsers = (await _local.listUsers()).map((u) => SimpleUser(u.id, u.name)).toList();
    final mode = session == SessionState.expired
        ? AuthGateMode.expired
        : localUsers.isNotEmpty
            ? AuthGateMode.found
            : AuthGateMode.landing;
    state = state.copyWith(
      ready: true,
      view: AppView.gate,
      auth: AuthUi(gateMode: mode, email: _api.email, offline: session == SessionState.offline, error: error, localUsers: localUsers),
    );
  }

  void _sessionLost() {
    if (state.view == AppView.gate) return;
    state = AppState.loading().copyWith(ready: true);
    _showGate(SessionState.expired);
  }

  /// Re-runs startup (the "Try again" button on the offline screen).
  Future<void> retry() async {
    state = AppState.loading();
    await _init();
  }

  /// Called with the Google ID token from the sign-in button.
  Future<void> signInWithGoogleToken(String idToken) async {
    try {
      await _api.signInWithGoogle(idToken);
    } on ApiException catch (e) {
      state = state.copyWith(auth: state.auth.copyWith(error: e.offline ? null : "Couldn't sign you in (${e.message}). Try again.", offline: e.offline));
      return;
    }
    await _afterSignIn(welcome: true);
  }

  void gateError(String message) => state = state.copyWith(auth: state.auth.copyWith(error: message));

  /// Decides what a freshly authenticated session needs: migrate device data,
  /// ask about a conflict, onboard a new account, or just load the profiles.
  Future<void> _afterSignIn({bool welcome = false}) async {
    final email = _api.email;
    try {
      final cloud = await _backend.listUsers();
      final local = (await _local.listUsers()).map((u) => SimpleUser(u.id, u.name)).toList();
      if (local.isNotEmpty) {
        if (cloud.isEmpty) {
          await _migrate(local);
        } else {
          state = state.copyWith(
            ready: true,
            view: AppView.conflict,
            auth: AuthUi(email: email, localUsers: local, cloudCount: cloud.length),
          );
        }
        return;
      }
      await _loadAccount(cloud.map((u) => SimpleUser(u.id, u.name)).toList(), welcome: welcome);
    } on ApiException catch (e) {
      if (e.status == 401) return; // _sessionLost already moved to the gate
      await _showGate(e.offline ? SessionState.offline : SessionState.signedOut, error: e.offline ? null : "Couldn't load your account (${e.message}).");
    }
  }

  /// [welcome] shows the "Welcome back" screen and holds it briefly so it
  /// doesn't just flash; a silent launch with a saved session goes straight in.
  Future<void> _loadAccount(List<SimpleUser> users, {bool welcome = false}) async {
    if (users.isEmpty) {
      state = state.copyWith(ready: true, view: AppView.onboarding, users: [], auth: AuthUi(email: _api.email));
      return;
    }
    final hold = Future.delayed(welcome ? const Duration(milliseconds: RestoreScreen.totalMs + 200) : Duration.zero);
    state = state.copyWith(ready: true, view: welcome ? AppView.restoring : AppView.loading, auth: AuthUi(email: _api.email));
    final activeStr = await _backend.getMeta('activeUser');
    final activeId = activeStr != null ? int.tryParse(activeStr) : null;
    if (activeId != null && users.any((u) => u.id == activeId)) {
      await loadUser(activeId, users, hold);
    } else if (users.length == 1) {
      await loadUser(users.first.id, users, hold);
    } else {
      await hold;
      state = state.copyWith(view: AppView.picker, users: users);
    }
  }

  /// One-time move of this device's profiles into the account. The device copy
  /// is only deleted after every profile has been confirmed saved.
  Future<void> _migrate(List<SimpleUser> local) async {
    state = state.copyWith(ready: true, view: AppView.migrating, auth: AuthUi(email: _api.email, localUsers: local));
    final idMap = <int, int>{};
    try {
      for (final u in local) {
        if (idMap.containsKey(u.id)) continue;
        final data = await _local.getUserData(u.id);
        final foods = await _local.getFoods(u.id);
        idMap[u.id] = await _backend.importProfile(localId: u.id, name: u.name, data: data, foods: foods);
        state = state.copyWith(auth: state.auth.copyWith(migratedIds: {...state.auth.migratedIds, u.id}));
      }
    } on ApiException catch (e) {
      state = state.copyWith(auth: state.auth.copyWith(error: e.offline ? "You're offline. Reconnect and try again." : "Couldn't save (${e.message}). Nothing was removed from this device."));
      return;
    }
    final active = int.tryParse(await _local.getMeta('activeUser') ?? '');
    if (active != null && idMap[active] != null) await _backend.setMeta('activeUser', idMap[active].toString());
    for (final u in local) {
      await _local.deleteUser(u.id);
    }
    state = state.copyWith(auth: state.auth.copyWith(migrationDone: true));
  }

  Future<void> retryMigration() async {
    final local = (await _local.listUsers()).map((u) => SimpleUser(u.id, u.name)).toList();
    state = state.copyWith(auth: state.auth.copyWith(error: null));
    await _migrate(local);
  }

  Future<void> finishMigration() async {
    final cloud = await _backend.listUsers();
    await _loadAccount(cloud.map((u) => SimpleUser(u.id, u.name)).toList());
  }

  /// The "account already has data" screen: keep both, or use the account's.
  Future<void> resolveConflict({required bool add}) async {
    final local = state.auth.localUsers;
    if (add) {
      await _migrate(local);
      return;
    }
    for (final u in local) {
      await _local.deleteUser(u.id);
    }
    await finishMigration();
  }

  Future<void> signOut() async {
    await _api.signOut();
    await _resetDevice();
  }

  Future<void> deleteAccount() async {
    try {
      await _backend.deleteAccount();
    } on ApiException catch (e) {
      notice.value = e.offline ? "You're offline. Reconnect to delete your account." : "Couldn't delete the account (${e.message}).";
      return;
    }
    await _api.clear();
    await _resetDevice();
  }

  Future<void> _resetDevice() async {
    _healthSyncTimer?.cancel();
    await _backend.clearMeta('activeUser');
    state = AppState.loading().copyWith(ready: true);
    await _showGate(SessionState.signedOut);
  }

  Future<void> loadUser(int id, [List<SimpleUser>? usersList, Future<void>? hold]) async {
    final ud = await _backend.getUserData(id);
    final data = AppData.fromMap(ud);
    final foodsRaw = await _backend.getFoods(id);
    final users = usersList ?? state.users;
    final user = users.firstWhere((u) => u.id == id, orElse: () => SimpleUser(id, data.settings['name'] ?? 'Me'));
    await _backend.setMeta('activeUser', id.toString());
    if (hold != null) await hold;
    AppTheme.set(data.settings['themeMode'] == 'light' ? Brightness.light : Brightness.dark);
    state = state.copyWith(
      data: data,
      foods: foodsRaw,
      user: user,
      users: users,
      view: AppView.app,
      tab: 'home',
    );
    // Sweep a finished 14-Day Calibration that's aged past its retention
    // window (the user could revisit its results from the Weight page until
    // now). One shot on load is enough — the results screen and the Weight-
    // page entry card each re-check on open too.
    final cal = data.calibration;
    if (cal != null && calibrationExpired(cal, todayStr(data.settings))) {
      await update('calibration', (_) => null);
    }
    // No HealthKit/Health Connect equivalent exists on web — skip entirely
    // rather than spend cycles on calls that can never succeed there.
    if (!kIsWeb) {
      // Fire-and-forget: don't block app launch on the health-store round
      // trip (and permission prompt, the first time) — the sync banner just
      // updates itself once this resolves.
      syncHealth();
      _healthSyncTimer?.cancel();
      _healthSyncTimer = Timer.periodic(_healthSyncInterval, (_) => syncHealth());
    }
  }

  @override
  void dispose() {
    _healthSyncTimer?.cancel();
    super.dispose();
  }

  /// Pulls today's steps + active kcal burned from Apple Health / Health
  /// Connect and merges them into today's activity entry, preserving any
  /// manually-logged cardio minutes. Updates [AppState.healthSyncStatus] /
  /// [AppState.healthLastSyncedAt] throughout so the UI can show real
  /// progress instead of a fire-and-forget with no visible trace.
  Future<bool> syncHealth() async {
    state = state.copyWith(healthSyncStatus: HealthSyncStatus.syncing);
    final result = await HealthService.instance.fetchToday();
    if (result == null) {
      state = state.copyWith(healthSyncStatus: HealthSyncStatus.failed);
      return false;
    }
    final today = todayStr(state.data.settings);
    await update('activity', (prev) {
      final a = Map<String, dynamic>.from(prev ?? {});
      final cur = Map<String, dynamic>.from(a[today] ?? {});
      a[today] = {'steps': result.steps, 'kcal': result.kcal, 'min': cur['min'] ?? 0};
      return a;
    });
    state = state.copyWith(healthSyncStatus: HealthSyncStatus.success, healthLastSyncedAt: DateTime.now());
    return true;
  }

  /// Optimistic: the screen updates immediately, the write goes to the API in
  /// the background, and a failed save puts the previous value back.
  Future<void> update(String key, dynamic Function(dynamic prev) fn) async {
    final prev = state.data[key];
    final next = fn(prev);
    final uid = state.user!.id;
    _applyKey(key, next);
    try {
      await _backend.setUserKV(uid, key, next);
    } on ApiException catch (e) {
      if (state.user?.id == uid) _applyKey(key, prev);
      notice.value = e.offline ? "You're offline — that change wasn't saved." : "Couldn't save that change (${e.message}).";
    }
  }

  void _applyKey(String key, dynamic next) {
    state = state.copyWith(data: state.data.copyWith(
      settings: key == 'settings' ? sanitizeSettings(Map<String, dynamic>.from(next)) : null,
      weight: key == 'weight' ? List<Map<String, dynamic>>.from(next) : null,
      history: key == 'history' ? Map<String, dynamic>.from(next) : null,
      sessions: key == 'sessions' ? Map<String, dynamic>.from(next) : null,
      diet: key == 'diet' ? Map<String, dynamic>.from(next) : null,
      water: key == 'water' ? Map<String, dynamic>.from(next) : null,
      activity: key == 'activity' ? Map<String, dynamic>.from(next) : null,
      plan: key == 'plan' ? (next == null ? null : Map<String, dynamic>.from(next)) : _unset,
      aiFoodMemory: key == 'aiFoodMemory' ? Map<String, dynamic>.from(next) : null,
      calibration: key == 'calibration' ? (next == null ? null : Map<String, dynamic>.from(next)) : _unset,
      muscle: key == 'muscle' ? (next == null ? null : Map<String, dynamic>.from(next)) : _unset,
    ));
  }

  /// Sets one key within `settings` and persists — replaces the "clone the
  /// settings map, mutate one field, `update('settings', ...)`" that was
  /// hand-rolled the same way in several screens (day-start time, theme
  /// mode, current weight, active training-plan schedule).
  Future<void> patchSettings(String key, dynamic value) {
    return update('settings', (prev) {
      final s = Map<String, dynamic>.from(prev ?? {});
      s[key] = value;
      return s;
    });
  }

  Future<void> addFood(String name, double kcal, double protein, [double carb = 0, double fat = 0, double fiber = 0]) async {
    final uid = state.user!.id;
    await _backend.addFood(uid, name, kcal, protein, carb, fat, fiber);
    final foods = await _backend.getFoods(uid);
    state = state.copyWith(foods: foods);
  }

  Future<void> updateFood(int id, String name, double kcal, double protein, double carb, double fat, double fiber) async {
    final uid = state.user!.id;
    await _backend.updateFood(uid, id, name, kcal, protein, carb, fat, fiber);
    final foods = await _backend.getFoods(uid);
    state = state.copyWith(foods: foods);
  }

  Future<void> removeFood(int id) async {
    final uid = state.user!.id;
    await _backend.deleteFood(uid, id);
    final foods = await _backend.getFoods(uid);
    state = state.copyWith(foods: foods);
  }

  Future<void> onboardingComplete(Map<String, dynamic> settings, Map<String, dynamic> plan, String name, double currentWeight, String today) async {
    final id = await _backend.addUser(name);
    await _backend.setUserKV(id, 'settings', settings);
    await _backend.setUserKV(id, 'plan', plan);
    await _backend.setUserKV(id, 'weight', [
      {'date': today, 'weight': currentWeight}
    ]);
    final users = await _backend.listUsers();
    final simpleUsers = users.map((u) => SimpleUser(u.id, u.name)).toList();
    await loadUser(id, simpleUsers);
  }

  Future<void> switchUser(int id) => loadUser(id);

  /// Permanently deletes a profile and everything tied to it. If [id] wasn't
  /// the active profile, only the in-memory user list needs to move — the
  /// data on screen right now belongs to someone else and is untouched. If
  /// it *was* active, this loads whichever profile is left (same reload
  /// [loadUser] already does for a normal switch), or — if it was the only
  /// profile — drops back to a clean, empty state so the caller lands on
  /// onboarding instead of showing a dead profile's leftover data.
  Future<void> deleteUser(int id) async {
    await _backend.deleteUser(id);
    final rows = await _backend.listUsers();
    final simpleUsers = rows.map((u) => SimpleUser(u.id, u.name)).toList();
    if (state.user?.id != id) {
      state = state.copyWith(users: simpleUsers);
      return;
    }
    if (simpleUsers.isNotEmpty) {
      await loadUser(simpleUsers.first.id, simpleUsers);
    } else {
      state = AppState(ready: true, view: AppView.onboarding, users: const [], user: null, data: AppData.empty, foods: const [], tab: 'home');
    }
  }

  void beginCreate() => state = state.copyWith(view: AppView.onboarding);

  void showPicker() => state = state.copyWith(view: AppView.picker);

  void setTab(String tab) => state = state.copyWith(tab: tab);
}

enum AppView { loading, gate, migrating, conflict, restoring, onboarding, picker, app }

/// Wording for the sign-in gate.
enum AuthGateMode { landing, found, expired }

/// Everything the pre-app account screens (gate, migration, conflict) show.
class AuthUi {
  final AuthGateMode gateMode;
  final String? email;
  final bool offline;
  final String? error;
  final List<SimpleUser> localUsers;
  final Set<int> migratedIds;
  final bool migrationDone;
  final int cloudCount;

  const AuthUi({
    this.gateMode = AuthGateMode.landing,
    this.email,
    this.offline = false,
    this.error,
    this.localUsers = const [],
    this.migratedIds = const {},
    this.migrationDone = false,
    this.cloudCount = 0,
  });

  AuthUi copyWith({bool? offline, Object? error = _unset, Set<int>? migratedIds, bool? migrationDone}) => AuthUi(
        gateMode: gateMode,
        email: email,
        offline: offline ?? this.offline,
        error: identical(error, _unset) ? this.error : error as String?,
        localUsers: localUsers,
        migratedIds: migratedIds ?? this.migratedIds,
        migrationDone: migrationDone ?? this.migrationDone,
        cloudCount: cloudCount,
      );
}

class AppState {
  final bool ready;
  final AppView view;
  final List<SimpleUser> users;
  final SimpleUser? user;
  final AppData data;
  final List<FoodRow> foods;
  final String tab;
  final HealthSyncStatus healthSyncStatus;
  final DateTime? healthLastSyncedAt;
  final AuthUi auth;

  /// Signed-in Google account email, for Settings > Account.
  String? get email => ApiClient.instance.email;

  const AppState({
    required this.ready,
    required this.view,
    required this.users,
    required this.user,
    required this.data,
    required this.foods,
    required this.tab,
    this.healthSyncStatus = HealthSyncStatus.idle,
    this.healthLastSyncedAt,
    this.auth = const AuthUi(),
  });

  factory AppState.loading() => const AppState(
        ready: false,
        view: AppView.loading,
        users: [],
        user: null,
        data: AppData.empty,
        foods: [],
        tab: 'home',
      );

  AppState copyWith({
    bool? ready,
    AppView? view,
    List<SimpleUser>? users,
    SimpleUser? user,
    AppData? data,
    List<FoodRow>? foods,
    String? tab,
    HealthSyncStatus? healthSyncStatus,
    Object? healthLastSyncedAt = _unset,
    AuthUi? auth,
  }) {
    return AppState(
      ready: ready ?? this.ready,
      view: view ?? this.view,
      users: users ?? this.users,
      user: user ?? this.user,
      data: data ?? this.data,
      foods: foods ?? this.foods,
      healthSyncStatus: healthSyncStatus ?? this.healthSyncStatus,
      healthLastSyncedAt: identical(healthLastSyncedAt, _unset) ? this.healthLastSyncedAt : healthLastSyncedAt as DateTime?,
      tab: tab ?? this.tab,
      auth: auth ?? this.auth,
    );
  }
}

final appControllerProvider = StateNotifierProvider<AppController, AppState>((ref) => AppController());
