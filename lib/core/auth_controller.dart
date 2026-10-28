import 'dart:async';

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
  static const _kLastActive = 'auth_last_active';

  final Dio _dio;
  final TokenStore _tokens;
  final SharedPreferences _prefs;
  final Future<void> Function()? warmUp;

  bool get isAuthenticated => _tokens.isAuthenticated;
  AppUser? get user => _tokens.user;
  String get role => _tokens.user?.role ?? 'reader';
  bool get isAdmin => _tokens.user?.isAdmin ?? false;
  bool get canEdit => _tokens.user?.canEdit ?? false;
  bool get canPurge => _tokens.user?.canPurge ?? false;
  bool get sessionExpired => _sessionExpired;

  bool _sessionExpired = false;

  Future<void> restore() async {
    final access = _prefs.getString(_kAccess);
    final storedRefresh = _prefs.getString(_kRefresh);
    if (access == null || storedRefresh == null) return;
    _tokens.accessToken = access;
    _tokens.refreshToken = storedRefresh;

    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      _tokens.user = AppUser.fromJson(response.data ?? const {});
      await _markActive();
      notifyListeners();
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
    final response = await guard(() async {
      return _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'username': username.trim(), 'password': password},
      );
    });
    await _applyTokens(response.data ?? const {});
  }

  Future<void> register({
    required String username,
    required String password,
    required String fullName,
  }) async {
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
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      final fresh = AppUser.fromJson(response.data ?? const {});
      final current = _tokens.user;
      if (current != null && current.role != fresh.role) {
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

  void clearSessionFlag() {
    _sessionExpired = false;
  }

  void substituteRole(String role) {
    final current = _tokens.user;
    if (current == null) return;
    _tokens.user = current.copyWith(role: role);
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
    final warm = warmUp;
    if (warm != null) {
      try {
        await warm();
      } catch (error) {
        debugPrint('Справочники не загружены: $error');
      }
    }
    notifyListeners();
  }

  Future<void> _markActive() async {
    await _prefs.setString(_kLastActive, DateTime.now().toIso8601String());
  }

  Future<void> _persist() async {
    await _prefs.setString(_kAccess, _tokens.accessToken!);
    await _prefs.setString(_kRefresh, _tokens.refreshToken!);
    await _markActive();
  }

  Future<void> _clearStored() async {
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
    await _prefs.remove(_kLastActive);
  }
}
