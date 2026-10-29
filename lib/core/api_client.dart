import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_debug.dart';
import 'api_exceptions.dart';
import 'api_log.dart';
import 'connection_observer.dart';
import 'config.dart';
import 'supabase_config.dart';
import 'token_store.dart';

Dio buildDio({
  required TokenStore tokens,
  Future<bool> Function()? onRefresh,
  void Function()? onNetworkError,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: SupabaseConfig.isConfigured
          ? SupabaseConfig.rest
          : resolvedApiBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        if (SupabaseConfig.isConfigured) ...{
          'apikey': SupabaseConfig.anonKey,
          'Prefer': 'return=representation',
        },
      },
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokens.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        if (SupabaseConfig.isConfigured) {
          options.headers['apikey'] = SupabaseConfig.anonKey;
          options.headers['Authorization'] ??=
              'Bearer ${SupabaseConfig.anonKey}';

          final path = options.path;
          if (path.startsWith('/auth/v1/')) {
            options.baseUrl = SupabaseConfig.url;
            if (path.contains('/token')) {
              options.headers['Authorization'] =
                  'Bearer ${SupabaseConfig.anonKey}';
            }
          }
        }

        final debugParams = ApiDebug.instance.queryParameters;
        if (debugParams.isNotEmpty) {
          options.queryParameters = {
            ...options.queryParameters,
            ...debugParams,
          };
        }

        options.extra['startedAt'] = DateTime.now();
        options.extra['journaled'] = false;
        return handler.next(options);
      },
      onResponse: (response, handler) {
        ConnectionObserver.instance.markOnline();
        _journal(response.requestOptions, response.statusCode, null);
        response.requestOptions.extra['journaled'] = true;

        final status = response.statusCode ?? 0;
        if (status >= 400) {
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        final options = error.requestOptions;
        final networkFailure =
            error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout;
        if (networkFailure && options.extra['skipOfflineTracking'] != true) {
          if (!options.path.startsWith('/auth/v1/')) {
            onNetworkError?.call();
          }
        }

        final isAuthCall =
            options.path.contains('/token') ||
            options.uri.path.contains('/token');
        final canRefresh =
            error.response?.statusCode == 401 &&
            onRefresh != null &&
            !isAuthCall &&
            options.extra['refreshed'] != true;
        if (canRefresh) {
          options.extra['refreshed'] = true;
          final ok = await onRefresh();
          if (ok) {
            options.extra['journaled'] = false;
            try {
              final retried = await dio.fetch<dynamic>(options);
              return handler.resolve(retried);
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
        }

        final attempt = (options.extra['attempt'] as int?) ?? 0;
        if (_shouldRetry(error) && attempt < 2) {
          options.extra['attempt'] = attempt + 1;
          options.extra['journaled'] = false;
          await Future<void>.delayed(
            Duration(milliseconds: 300 * (attempt + 1)),
          );
          try {
            final retried = await dio.fetch<dynamic>(options);
            return handler.resolve(retried);
          } on DioException catch (e) {
            return handler.next(e);
          }
        }

        if (options.extra['journaled'] != true) {
          _journal(options, error.response?.statusCode, error.type.name);
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
}

bool _shouldRetry(DioException error) {
  if (error.requestOptions.method.toUpperCase() != 'GET') return false;
  if (error.type == DioExceptionType.cancel) return false;
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.connectionError) {
    return true;
  }
  final status = error.response?.statusCode ?? 0;
  return status >= 500;
}

void _journal(RequestOptions options, int? status, String? error) {
  final startedAt = options.extra['startedAt'];
  final duration = startedAt is DateTime
      ? DateTime.now().difference(startedAt).inMilliseconds
      : 0;

  final entry = ApiLogEntry(
    at: DateTime.now(),
    method: options.method.toUpperCase(),
    path: options.uri.toString(),
    status: status,
    durationMs: duration,
    error: error,
  );

  ApiLog.instance.add(entry);

  if (kDebugMode) {
    debugPrint(
      '[API] ${entry.method} ${options.path} -> ${status ?? 'сбой'} '
      '(${entry.durationMs} мс)',
    );
  }
}
