import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import 'api_exceptions.dart';
import 'token_store.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._dio, this._tokens, this._prefs, {this.warmUp});

  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';

  final Dio _dio;
  final TokenStore _tokens;
  final SharedPreferences _prefs;

  /// Прогрев справочников после входа. Выполняется до уведомления
  /// слушателей, чтобы первый экран списка сразу видел названия связей.
  final Future<void> Function()? warmUp;

  bool get isAuthenticated => _tokens.isAuthenticated;
  AppUser? get user => _tokens.user;
  bool get isAdmin => _tokens.user?.isAdmin ?? false;

  Future<void> restore() async {
    final access = _prefs.getString(_kAccess);
    final refresh = _prefs.getString(_kRefresh);
    if (access == null || refresh == null) return;
    _tokens.accessToken = access;
    _tokens.refreshToken = refresh;

    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      final user = AppUser.fromJson(response.data ?? const {});
      _tokens.user = user;
      notifyListeners();
    } on DioException {
      _tokens.clear();
      await _clearStored();
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    final response = await guard(() async {
      return _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'username': username.trim(), 'password': password},
      );
    });

    final data = response.data ?? const <String, dynamic>{};
    _tokens.set(
      accessToken: '${data['accessToken']}',
      refreshToken: '${data['refreshToken']}',
      user: AppUser.fromJson(
        (data['user'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
    );

    await _prefs.setString(_kAccess, _tokens.accessToken!);
    await _prefs.setString(_kRefresh, _tokens.refreshToken!);
    try {
      await warmUp?.call();
    } catch (error) {
      debugPrint('Справочники не загружены: $error');
    }
    notifyListeners();
  }

  Future<bool> refresh() async {
    final refreshToken = _tokens.refreshToken;
    if (refreshToken == null) return false;

    try {
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
      await _prefs.setString(_kAccess, _tokens.accessToken!);
      await _prefs.setString(_kRefresh, _tokens.refreshToken!);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    final refreshToken = _tokens.refreshToken;
    if (refreshToken != null) {
      try {
        await _dio.post<void>(
          '/auth/logout',
          data: {'refreshToken': refreshToken},
        );
      } catch (_) {}
    }
    _tokens.clear();
    await _clearStored();
    notifyListeners();
  }

  Future<void> _clearStored() async {
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
  }
}
