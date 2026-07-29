import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/lib/storage.dart';
import '../shared/lib/health_service.dart';
import '../shared/lib/helpers.dart';
import '../shared/theme.dart';

/// Mirrors the React app's DEFAULT_DATA / AppContext shape.
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
  });

  static const empty = AppData();

  factory AppData.fromMap(Map<String, dynamic> m) => AppData(
        settings: Map<String, dynamic>.from(m['settings'] ?? {}),
        weight: List<Map<String, dynamic>>.from((m['weight'] ?? []).map((e) => Map<String, dynamic>.from(e))),
        history: Map<String, dynamic>.from(m['history'] ?? {}),
        sessions: Map<String, dynamic>.from(m['sessions'] ?? {}),
        diet: Map<String, dynamic>.from(m['diet'] ?? {}),
        water: Map<String, dynamic>.from(m['water'] ?? {}),
        activity: Map<String, dynamic>.from(m['activity'] ?? {}),
        photos: List<dynamic>.from(m['photos'] ?? []),
        plan: m['plan'] != null ? Map<String, dynamic>.from(m['plan']) : null,
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
  Timer? _healthSyncTimer;

  static const _healthSyncInterval = Duration(minutes: 5);

  Future<void> _init() async {
    await _backend.init();
    final users = await _backend.listUsers();
    final activeStr = await _backend.getMeta('activeUser');
    final activeId = activeStr != null ? int.tryParse(activeStr) : null;
    if (users.isEmpty) {
      state = state.copyWith(view: AppView.onboarding, users: [], ready: true);
      return;
    }
    final simpleUsers = users.map((u) => SimpleUser(u.id, u.name)).toList();
    if (activeId != null && users.any((u) => u.id == activeId)) {
      await loadUser(activeId, simpleUsers);
      state = state.copyWith(ready: true);
    } else {
      state = state.copyWith(view: AppView.picker, users: simpleUsers, ready: true);
    }
  }

  Future<void> loadUser(int id, [List<SimpleUser>? usersList]) async {
    final ud = await _backend.getUserData(id);
    final data = AppData.fromMap(ud);
    final foodsRaw = await _backend.getFoods(id);
    final users = usersList ?? state.users;
    final user = users.firstWhere((u) => u.id == id, orElse: () => SimpleUser(id, data.settings['name'] ?? 'Me'));
    await _backend.setMeta('activeUser', id.toString());
    AppTheme.set(data.settings['themeMode'] == 'light' ? Brightness.light : Brightness.dark);
    state = state.copyWith(
      data: data,
      foods: foodsRaw,
      user: user,
      users: users,
      view: AppView.app,
      tab: 'home',
    );
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

  Future<void> update(String key, dynamic Function(dynamic prev) fn) async {
    final prev = state.data[key];
    final next = fn(prev);
    final uid = state.user!.id;
    await _backend.setUserKV(uid, key, next);
    state = state.copyWith(data: state.data.copyWith(
      settings: key == 'settings' ? Map<String, dynamic>.from(next) : null,
      weight: key == 'weight' ? List<Map<String, dynamic>>.from(next) : null,
      history: key == 'history' ? Map<String, dynamic>.from(next) : null,
      sessions: key == 'sessions' ? Map<String, dynamic>.from(next) : null,
      diet: key == 'diet' ? Map<String, dynamic>.from(next) : null,
      water: key == 'water' ? Map<String, dynamic>.from(next) : null,
      activity: key == 'activity' ? Map<String, dynamic>.from(next) : null,
      plan: key == 'plan' ? (next == null ? null : Map<String, dynamic>.from(next)) : _unset,
    ));
  }

  Future<void> addFood(String name, double kcal, double protein, [double carb = 0, double fat = 0, double fiber = 0]) async {
    final uid = state.user!.id;
    await _backend.addFood(uid, name, kcal, protein, carb, fat, fiber);
    final foods = await _backend.getFoods(uid);
    state = state.copyWith(foods: foods);
  }

  Future<void> updateFood(int id, String name, double kcal, double protein, double carb, double fat, double fiber) async {
    final uid = state.user!.id;
    await _backend.updateFood(id, name, kcal, protein, carb, fat, fiber);
    final foods = await _backend.getFoods(uid);
    state = state.copyWith(foods: foods);
  }

  Future<void> removeFood(int id) async {
    final uid = state.user!.id;
    await _backend.deleteFood(id);
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

  void beginCreate() => state = state.copyWith(view: AppView.onboarding);

  void showPicker() => state = state.copyWith(view: AppView.picker);

  void setTab(String tab) => state = state.copyWith(tab: tab);
}

enum AppView { loading, onboarding, picker, app }

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
    );
  }
}

final appControllerProvider = StateNotifierProvider<AppController, AppState>((ref) => AppController());
