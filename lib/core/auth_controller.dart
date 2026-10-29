import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import 'api_exceptions.dart';
import 'jwt.dart';
import 'supabase_config.dart';
import 'supabase_auth_api.dart';
import 'token_store.dart';

class AuthController extends ChangeNotifier {
  AuthController(
    this._dio,
    this._tokens,
    this._prefs, {
    this.warmUp,
    SupabaseAuthApi? supabase,
  }) : _supabase = supabase;

  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kLastActive = 'auth_last_active';
  static const _kUser = 'auth_user';

  final Dio _dio;
  final TokenStore _tokens;
  final SharedPreferences _prefs;
  final SupabaseAuthApi? _supabase;
  final Future<void> Function()? warmUp;

  bool get isAuthenticated => _tokens.isAuthenticated;
  AppUser? get user => _tokens.user;
  String get role => _tokens.user?.role ?? 'reader';
  bool get isAdmin => _tokens.user?.isAdmin ?? false;
  bool get canEdit => _tokens.user?.canEdit ?? false;
  bool get canPurge => _tokens.user?.canPurge ?? false;
  bool get sessionExpired => _sessionExpired;
  bool get usesSupabase => _supabase != null && SupabaseConfig.isConfigured;

  bool _sessionExpired = false;

  Future<void> restore() async {
    final access = _prefs.getString(_kAccess);
    final storedRefresh = _prefs.getString(_kRefresh);
    if (access == null || storedRefresh == null) return;
    _tokens.accessToken = access;
    _tokens.refreshToken = storedRefresh;
    _tokens.user = _storedUser();
    if (_tokens.user != null) notifyListeners();
    final startedAt = DateTime.now();

    if (usesSupabase) {
      // В облачном режиме профиль лежит в app_users и доступен по токену.
      // Если проверка не удалась, но ответ сервера пришёл за то же время,
      // значит проблема не в сети — токен просрочен, сессию надо обновить.
      try {
        final me = await _loadProfile();
        if (me == null) {
          // Токен принят, но строки в app_users нет — сессию не восстанавливаем.
          _tokens.clear();
          await _clearStored();
          notifyListeners();
          return;
        }
        _tokens.user = me;
        await _persist();
      } on ApiException {
        final fast =
            DateTime.now().difference(startedAt) < const Duration(seconds: 3);
        if (fast && !await refresh()) {
          _tokens.clear();
          await _clearStored();
          _sessionExpired = true;
          notifyListeners();
          return;
        }
      }
      await _markActive();
      notifyListeners();
      return;
    }

    try {
      final me = await _loadProfile();
      if (me == null) {
        final renewed = await refresh();
        if (!renewed) {
          _tokens.clear();
          await _clearStored();
        }
      } else {
        _tokens.user = me;
        await _markActive();
        notifyListeners();
      }
    } on NetworkException {
      return;
    } on ApiException {
      final renewed = await refresh();
      if (!renewed) {
        _tokens.clear();
        await _clearStored();
        notifyListeners();
      }
    }
  }

  Future<void> login(String username, String password) async {
    if (usesSupabase) {
      await _supabaseLogin(username, password);
      return;
    }
    final response = await guard(() async {
      return _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'username': username.trim(), 'password': password},
      );
    });
    await _applyTokens(response.data ?? const {});
  }

  Future<void> _supabaseLogin(String login, String password) async {
    final email = login.contains('@') ? login.trim() : '$login@habit.local';
    final session = <String, dynamic>{
      ...await _supabase!.signIn(email, password),
    };
    if (session['access_token'] == null) {
      throw const UnauthorizedException('Неверный логин или пароль');
    }
    // Облачный сбой CORS при проверке токена выглядит как Generic-ответ
    // шлюза — повторяем вход свежими данными, прежде чем показывать ошибку.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _applySupabaseSession(session);
        return;
      } catch (error) {
        final temporary =
            error is UnauthorizedException ||
            error is ServerException ||
            error is NetworkException;
        if (!temporary || attempt == 1) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 700));
        final retry = await _supabase.signIn(email, password);
        if (retry['access_token'] == null) {
          throw const UnauthorizedException('Неверный логин или пароль');
        }
        session
          ..clear()
          ..addAll(retry);
      }
    }
  }

  Future<void> register({
    required String username,
    required String password,
    required String fullName,
  }) async {
    if (usesSupabase) {
      throw const ForbiddenException(
        'В облачной версии регистрация выполняется администратором',
      );
    }
    final response = await guard(() async {
      return _dio.post<Map<String, dynamic>>(
        '/auth/register-strict',
        data: {
          'username': username.trim(),
          'password': password,
          'fullName': fullName.trim(),
        },
      );
    });
    await _applyTokens(response.data ?? const {});
  }

  Future<bool> refresh() async {
    final refreshToken = _tokens.refreshToken;
    if (refreshToken == null) return false;

    try {
      if (usesSupabase) {
        final session = await _supabase!.refresh(refreshToken);
        if (session['access_token'] == null) return false;
        await _applySupabaseSession(session, notify: true);
        return true;
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data ?? const <String, dynamic>{};
      if (data['accessToken'] == null) return false;

      _tokens.set(
        accessToken: '${data['accessToken']}',
        refreshToken: '${data['refreshToken']}',
        user: AppUser.fromJson(
          (data['user'] as Map?)?.cast<String, dynamic>() ?? {},
        ),
      );
      await _persist();
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('Обновление токена не удалось: $error');
      _sessionExpired = true;
      _tokens.clear();
      await _clearStored();
      notifyListeners();
      return false;
    }
  }

  Future<bool> checkSession() async {
    if (!isAuthenticated) return false;
    try {
      final fresh = await _loadProfile();
      if (fresh == null) {
        _sessionExpired = true;
        return false;
      }
      final current = _tokens.user;
      if (current == null || current.role != fresh.role) {
        _tokens.user = fresh;
        notifyListeners();
      }
      await _markActive();
      return true;
    } on UnauthorizedException {
      _sessionExpired = true;
      return false;
    } on ApiException {
      return true;
    }
  }

  Future<void> logout() async {
    final refreshToken = _tokens.refreshToken;
    if (refreshToken != null && !usesSupabase) {
      try {
        await _dio.post<void>(
          '/auth/logout',
          data: {'refreshToken': refreshToken},
        );
      } catch (_) {}
    }
    // Всегда удаляем ключи с текущего адреса — и старые ключи Flutter
    // (flutter.*), которые остались от предыдущих версий приложения.
    await _clearStored();
    try {
      final shared = await SharedPreferences.getInstance();
      for (final key in shared.getKeys().toList()) {
        if (key.startsWith('flutter.')) {
          await shared.remove(key);
        }
      }
    } catch (_) {}
    _tokens.clear();
    notifyListeners();
  }

  void clearSessionFlag() {
    _sessionExpired = false;
  }

  void substituteRole(String role) {
    final current = _tokens.user;
    if (current == null) return;
    _tokens.user = current.copyWith(role: role);
    notifyListeners();
  }

  Future<AppUser?> _loadProfile() async {
    if (usesSupabase) {
      final id = jwtSubject(_tokens.accessToken);
      if (id == null) return null;
      final row = await _supabase!.profile(id);
      if (row == null) return null;
      return AppUser.fromJson({
        'id': 0,
        'username': row['username'] ?? '',
        'fullName': row['full_name'] ?? row['username'] ?? '',
        'role': row['role'] ?? 'reader',
        'profileId': row['profile_id'],
      });
    }
    final response = await _dio.get<Map<String, dynamic>>('/auth/me');
    return AppUser.fromJson(response.data ?? const {});
  }

  Future<void> _applySupabaseSession(
    Map<String, dynamic> session, {
    bool notify = false,
  }) async {
    _sessionExpired = false;
    _tokens.accessToken = '${session['access_token']}';
    _tokens.refreshToken = '${session['refresh_token']}';
    AppUser? profile;
    try {
      profile = await _loadProfile();
    } on ApiException {
      debugPrint('Профиль не загружен, берём данные из сессии');
    }
    if (profile == null) {
      // Резервный вариант: роль по e-mail из профиля демо-пользователя,
      // чтобы администратор не оказывался «читателем» при сбое запроса.
      _tokens.user = AppUser.fromJson(
        _supabase!.userFromSession(session),
      ).copyWith(role: _roleHintFromEmail('${session['user']?['email']}'));
    } else {
      _tokens.user = profile;
    }
    await _persist();
    if (!notify) {
      try {
        await warmUp?.call();
      } catch (error) {
        debugPrint('Справочники не загружены: $error');
      }
    }
    notifyListeners();
  }

  Future<void> _applyTokens(Map<String, dynamic> data) async {
    _sessionExpired = false;
    _tokens.set(
      accessToken: '${data['accessToken']}',
      refreshToken: '${data['refreshToken']}',
      user: AppUser.fromJson(
        (data['user'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
    );
    await _persist();
    try {
      await warmUp?.call();
    } catch (error) {
      debugPrint('Справочники не загружены: $error');
    }
    notifyListeners();
  }

  /// Роль по адресу почты — только как подсказка, если профиль из
  /// app_users временно недоступен. Настоящие права всё равно проверяет
  /// сервер по данным таблицы.
  String _roleHintFromEmail(String email) {
    final name = email.split('@').first.toLowerCase();
    return switch (name) {
      'admin' => 'admin',
      'librarian' => 'librarian',
      _ => 'reader',
    };
  }

  Future<void> _markActive() async {
    await _prefs.setString(_kLastActive, DateTime.now().toIso8601String());
  }

  Future<void> _persist() async {
    await _prefs.setString(_kAccess, _tokens.accessToken!);
    await _prefs.setString(_kRefresh, _tokens.refreshToken!);
    final user = _tokens.user;
    if (user != null) {
      await _prefs.setString(_kUser, jsonEncode(user.toJson()));
    }
    await _markActive();
  }

  /// Профиль, сохранённый при последнем входе (нужен, чтобы после
  /// перезагрузки страницы сразу знать роль, пока идёт проверка сессии).
  AppUser? _storedUser() {
    final saved = _prefs.getString(_kUser);
    if (saved == null || saved.isEmpty) return null;
    try {
      return AppUser.fromJson(
        (jsonDecode(saved) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearStored() async {
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
    await _prefs.remove(_kLastActive);
    await _prefs.remove(_kUser);
  }
}
