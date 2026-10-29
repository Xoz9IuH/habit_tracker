import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_exceptions.dart';

class SupabaseAuthApi {
  SupabaseAuthApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> signIn(String email, String password) async {
    final response = await _send('/auth/v1/token?grant_type=password', {
      'email': email.trim(),
      'password': password,
    });
    return response.data ?? const <String, dynamic>{};
  }

  Future<Response<T>> _send<T>(String path, Map<String, dynamic> data) {
    return guard(() async {
      return _dio.post<T>(
        path,
        data: data,
        options: Options(extra: const {'skipOfflineTracking': true}),
      );
    });
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final response = await guard(() async {
      return _dio.post<Map<String, dynamic>>(
        '/auth/v1/token?grant_type=refresh_token',
        data: {'refresh_token': refreshToken},
      );
    });
    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> profile(String userId) async {
    final response = await guard(() async {
      return _dio.get<List<dynamic>>(
        '/app_users',
        queryParameters: {
          'id': 'eq.$userId',
          'select': 'username,full_name,role,profile_id',
          'limit': 1,
        },
      );
    });
    final rows = response.data ?? const [];
    if (rows.isEmpty) return null;
    return (rows.first as Map).cast<String, dynamic>();
  }

  Map<String, dynamic> userFromSession(Map<String, dynamic> session) {
    final user = (session['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final meta = (user['user_metadata'] as Map?)?.cast<String, dynamic>() ?? {};
    return {
      'id': user['id'],
      'email': user['email'],
      'username': meta['username'] ?? '',
      'fullName': meta['full_name'] ?? '',
    };
  }

  String? decodeSubject(String token) {
    try {
      final part = token.split('.').first;
      final padded = part.replaceAll('-', '+').replaceAll('_', '/');
      final normalised = padded.padRight(
        padded.length + (4 - padded.length % 4) % 4,
        '=',
      );
      final payload = jsonDecode(utf8.decode(base64.decode(normalised))) as Map;
      return payload['sub'] as String?;
    } catch (_) {
      return null;
    }
  }
}
