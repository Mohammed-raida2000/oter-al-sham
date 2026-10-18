import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

typedef Json = Map<String, dynamic>;

class ApiException implements Exception {
  final int status;
  final String message;
  final Json body;
  ApiException(this.status, this.message, [this.body = const {}]);
  @override
  String toString() => message;
}

class AppState extends ChangeNotifier {
  static const _store = FlutterSecureStorage();
  bool ready = false, showSplash = false, dark = false;
  String locale = 'ar', baseUrl = '';
  String? token;
  Json? user;

  bool can(String code) => ((user?['permissions'] as List?) ?? const []).contains(code);
  String get role => (user?['role'] ?? '') as String;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    locale = p.getString('locale') ?? 'ar';
    dark = p.getBool('dark') ?? false;
    baseUrl = p.getString('base') ?? '';
    final first = !(p.getBool('seen') ?? false);
    try {
      token = await _store.read(key: 'token');
    } catch (_) {
      token = null;
    }
    if (token != null && baseUrl.isNotEmpty) {
      try {
        user = Json.from(await get('/auth/me') as Map);
      } catch (_) {
        user = null;
      }
    }
    ready = true;
    showSplash = first;
    notifyListeners();
    if (first) {
      await Future.delayed(const Duration(seconds: 4));
      await p.setBool('seen', true);
      showSplash = false;
      notifyListeners();
    }
  }

  Future<dynamic> _req(String method, String path, {Map<String, dynamic>? q, Object? body}) async {
    final uri = Uri.parse('$baseUrl/api/v1$path').replace(queryParameters: q?.map((k, v) => MapEntry(k, '$v')));
    final h = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    http.Response r;
    try {
      final enc = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'POST':
          r = await http.post(uri, headers: h, body: enc).timeout(const Duration(seconds: 25));
          break;
        case 'PATCH':
          r = await http.patch(uri, headers: h, body: enc).timeout(const Duration(seconds: 25));
          break;
        case 'DELETE':
          r = await http.delete(uri, headers: h).timeout(const Duration(seconds: 25));
          break;
        default:
          r = await http.get(uri, headers: h).timeout(const Duration(seconds: 25));
      }
    } catch (_) {
      throw ApiException(0, 'network');
    }
    dynamic data;
    if (r.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(r.bodyBytes));
      } catch (_) {
        data = null;
      }
    }
    if (r.statusCode >= 400) {
      final m = data is Map ? Json.from(data) : <String, dynamic>{};
      if (r.statusCode == 401 && token != null && path != '/auth/login') {
        token = null;
        user = null;
        _store.delete(key: 'token');
        notifyListeners();
      }
      String msg = (m['message'] ?? 'error').toString();
      if (r.statusCode == 422 && m['errors'] is Map) {
        final first = (m['errors'] as Map).values.first;
        msg = first is List && first.isNotEmpty ? first.first.toString() : 'validation';
      }
      throw ApiException(r.statusCode, r.statusCode == 429 ? 'too_many' : msg, m);
    }
    return data;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? q}) => _req('GET', path, q: q);
  Future<dynamic> post(String path, [Object? body]) => _req('POST', path, body: body ?? {});
  Future<dynamic> patch(String path, Object body) => _req('PATCH', path, body: body);
  Future<dynamic> del(String path) => _req('DELETE', path);

  Future<void> login(String base, String u, String p) async {
    baseUrl = base.trim().replaceAll(RegExp(r'/+$'), '');
    final sp = await SharedPreferences.getInstance();
    await sp.setString('base', baseUrl);
    final r = await _req('POST', '/auth/login', body: {'username': u.trim(), 'password': p}) as Map;
    token = r['token'] as String;
    await _store.write(key: 'token', value: token);
    user = Json.from(r['user'] as Map);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _req('POST', '/auth/logout');
    } catch (_) {}
    token = null;
    user = null;
    try {
      await _store.delete(key: 'token');
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setLocale(String l) async {
    locale = l;
    (await SharedPreferences.getInstance()).setString('locale', l);
    notifyListeners();
    if (token != null) {
      try {
        await patch('/auth/preferences', {'locale': l});
      } catch (_) {}
    }
  }

  Future<void> setDark(bool v) async {
    dark = v;
    (await SharedPreferences.getInstance()).setBool('dark', v);
    notifyListeners();
    if (token != null) {
      try {
        await patch('/auth/preferences', {'theme': v ? 'dark' : 'light'});
      } catch (_) {}
    }
  }
}
