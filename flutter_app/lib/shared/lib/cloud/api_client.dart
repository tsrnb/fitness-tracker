import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Build-time endpoints (see `secrets.example.json`). Nothing here is secret —
/// the API is protected by the user's session, not by these values.
class CloudConfig {
  static const _api = String.fromEnvironment('API_URL');
  static const _ai = String.fromEnvironment('AI_URL');
  static const _cdn = String.fromEnvironment('CDN_URL');
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static String _trim(String s) => s.endsWith('/') ? s.substring(0, s.length - 1) : s;
  static String get apiUrl => _trim(_api);
  static String get aiUrl => _trim(_ai);
  static String get cdnUrl => _trim(_cdn);
}

class ApiException implements Exception {
  final int status; // 0 = couldn't reach the server
  final String message;
  const ApiException(this.status, this.message);
  bool get offline => status == 0;
  @override
  String toString() => 'ApiException($status): $message';
}

enum SessionState { signedOut, signedIn, expired, offline }

/// Holds the session (Google sign-in -> our own access + refresh tokens) and
/// makes authenticated JSON calls, refreshing the access token when it lapses.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _refreshKey = 'ct_refresh';
  static const _emailKey = 'ct_email';
  static const _nameKey = 'ct_name';
  static const _timeout = Duration(seconds: 20);
  static const _refreshEvery = Duration(minutes: 45); // access tokens last 60

  final _store = const FlutterSecureStorage();
  String? _access;
  String? _refresh;
  String? email;
  String? name;
  Timer? _timer;
  Future<void>? _refreshing;

  /// Fires when a refresh is rejected mid-session, so the app can show the
  /// "sign in again" screen.
  void Function()? onSessionLost;

  String? get accessToken => _access;
  bool get signedIn => _access != null;

  Future<SessionState> restore() async {
    try {
      _refresh = await _store.read(key: _refreshKey);
      email = await _store.read(key: _emailKey);
      name = await _store.read(key: _nameKey);
    } catch (_) {
      _refresh = null;
    }
    if (_refresh == null) return SessionState.signedOut;
    try {
      await _doRefresh();
      return SessionState.signedIn;
    } on ApiException catch (e) {
      return e.offline ? SessionState.offline : SessionState.expired;
    }
  }

  Future<void> signInWithGoogle(String idToken) async {
    final res = await _send('POST', '/auth/google', {'idToken': idToken}, auth: false);
    await _adopt(res);
    email = (res['user']?['email'] as String?) ?? email;
    name = (res['user']?['name'] as String?) ?? name;
    await _store.write(key: _emailKey, value: email ?? '');
    await _store.write(key: _nameKey, value: name ?? '');
  }

  Future<void> signOut() async {
    final r = _refresh;
    if (r != null && _access != null) {
      try {
        await _send('POST', '/auth/logout', {'refreshToken': r});
      } catch (_) {}
    }
    await clear();
  }

  Future<void> clear() async {
    _timer?.cancel();
    _access = null;
    _refresh = null;
    email = null;
    name = null;
    for (final k in [_refreshKey, _emailKey, _nameKey]) {
      try {
        await _store.delete(key: k);
      } catch (_) {}
    }
  }

  Future<void> _adopt(Map<String, dynamic> res) async {
    _access = res['accessToken'] as String;
    _refresh = res['refreshToken'] as String;
    await _store.write(key: _refreshKey, value: _refresh);
    _timer?.cancel();
    _timer = Timer.periodic(_refreshEvery, (_) => _doRefresh().catchError((_) {}));
  }

  /// Single-flight: concurrent 401s share one refresh (refresh tokens are one-time use).
  Future<void> _doRefresh() {
    return _refreshing ??= () async {
      try {
        final r = _refresh;
        if (r == null) throw const ApiException(401, 'no session');
        final res = await _send('POST', '/auth/refresh', {'refreshToken': r}, auth: false);
        await _adopt(res);
      } finally {
        _refreshing = null;
      }
    }();
  }

  Future<Map<String, dynamic>> get(String path) => _authed('GET', path);
  Future<Map<String, dynamic>> post(String path, [Object? body]) => _authed('POST', path, body);
  Future<Map<String, dynamic>> put(String path, [Object? body]) => _authed('PUT', path, body);
  Future<Map<String, dynamic>> patch(String path, [Object? body]) => _authed('PATCH', path, body);
  Future<Map<String, dynamic>> delete(String path) => _authed('DELETE', path);

  Future<Map<String, dynamic>> _authed(String method, String path, [Object? body]) async {
    try {
      return await _send(method, path, body);
    } on ApiException catch (e) {
      if (e.status != 401) rethrow;
    }
    try {
      await _doRefresh();
    } on ApiException catch (e) {
      if (!e.offline) onSessionLost?.call();
      rethrow;
    }
    return _send(method, path, body);
  }

  Future<Map<String, dynamic>> _send(String method, String path, Object? body, {bool auth = true}) async {
    final base = CloudConfig.apiUrl;
    if (base.isEmpty) throw const ApiException(0, 'API_URL is not configured');
    final req = http.Request(method, Uri.parse('$base$path'));
    req.headers['Content-Type'] = 'application/json';
    if (auth && _access != null) req.headers['Authorization'] = 'Bearer $_access';
    if (body != null) req.body = jsonEncode(body);
    http.Response res;
    try {
      res = await http.Response.fromStream(await req.send().timeout(_timeout));
    } catch (_) {
      throw const ApiException(0, 'offline');
    }
    Map<String, dynamic> out = {};
    if (res.body.isNotEmpty) {
      try {
        final d = jsonDecode(res.body);
        if (d is Map<String, dynamic>) out = d;
      } catch (_) {}
    }
    if (res.statusCode >= 400) throw ApiException(res.statusCode, (out['error'] as String?) ?? 'request failed');
    return out;
  }
}
